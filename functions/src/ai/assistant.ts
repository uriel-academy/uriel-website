import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';
import axios from 'axios';

// Use admin.firestore() inside functions to avoid duplicate-init/order issues

const OPENAI_KEY = functions.config().openai?.key;
const PINECONE_KEY = functions.config().pinecone?.key;
const PINECONE_ENV = functions.config().pinecone?.env; // e.g. "us-west1-gcp"
const PINECONE_INDEX = functions.config().pinecone?.index;

if (!OPENAI_KEY) {
  console.warn('OpenAI key not configured: set functions config openai.key');
}

const client = new OpenAI({ apiKey: OPENAI_KEY });

// cosine similarity
function cosine(a: number[], b: number[]) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += (a[i] || 0) * (b[i] || 0);
    na += (a[i] || 0) * (a[i] || 0);
    nb += (b[i] || 0) * (b[i] || 0);
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb) + 1e-12);
}

async function retrieveFromFirestore(queryEmbedding: number[], topK = 4) {
  // WARNING: This is only suitable for small corpora. For production use a vector DB.
  const docsSnap = await admin.firestore().collection('docs').get();
  const scored: Array<{ id: string; score: number; title?: string; excerpt?: string }> = [];
  docsSnap.forEach(doc => {
    const data: any = doc.data();
    if (!data.embedding) return;
    const score = cosine(queryEmbedding, data.embedding);
    scored.push({ id: doc.id, score, title: data.title, excerpt: (data.text || '').slice(0, 800) });
  });
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, topK);
}

async function retrieveFromPinecone(queryEmbedding: number[], topK = 4) {
  // Use Pinecone query API (expects vector in body)
  if (!PINECONE_KEY || !PINECONE_ENV || !PINECONE_INDEX) return [];
  const url = `https://${PINECONE_INDEX}-${PINECONE_ENV}.svc.pinecone.io/query`;
  try {
    const resp = await axios.post(url, {
      vector: queryEmbedding,
      topK,
      includeMetadata: true
    }, {
      headers: { 'Api-Key': PINECONE_KEY, 'Content-Type': 'application/json' }
    });
    const matches = resp.data.matches || [];
    return matches.map((m: any) => ({ id: m.id, score: m.score, title: m.metadata?.title, excerpt: m.metadata?.text?.slice(0, 800) }));
  } catch (e) {
    const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
    console.error('Pinecone query error', errMsg);
    return [];
  }
}

export const aiChat = functions.https.onCall(async (data, context) => {
  // Wrap the entire callable in a try/catch so we can log details and return HttpsError with
  // a readable message instead of an opaque internal error on the client.
  try {
    // Require callers to be authenticated. Use an any-cast to avoid @types mismatches
    const _ctx: any = context;
    const uid = _ctx?.auth?.uid;
    if (!uid) {
      functions.logger.warn('aiChat rejected unauthenticated request');
      throw new functions.https.HttpsError('unauthenticated', 'You must be signed in to use the assistant');
    }
  const _data: any = data;
  const question: string = (_data?.message || '').toString();
  const mode: 'rag' | 'chat' = _data?.mode === 'chat' ? 'chat' : 'rag';
    if (!question || question.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Empty message');
    }

    if (!OPENAI_KEY) {
      functions.logger.error('OpenAI key not configured in functions config');
      throw new functions.https.HttpsError('failed-precondition', 'AI provider not configured');
    }

    // Moderation
    try {
      const mod = await client.moderations.create({ model: 'omni-moderation-latest', input: question });
      const flagged = (mod as any).results?.[0]?.flagged;
      if (flagged) {
        throw new functions.https.HttpsError('permission-denied', 'Message flagged by moderation');
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      functions.logger.warn('Moderation failed or flagged:', errMsg);
      // Continue — moderation failure shouldn't prevent chat unless explicitly flagged
      if ((e as any)?.code === 'permission-denied') throw e;
    }

    // Retrieval (RAG)
    let retrieved: Array<{ id: string; score: number; title?: string; excerpt?: string }> = [];
    if (mode === 'rag') {
      try {
        const emb = await client.embeddings.create({ model: 'text-embedding-3-small', input: question });
        const qVec = emb.data?.[0]?.embedding;
        if (qVec && qVec.length) {
          if (PINECONE_KEY && PINECONE_ENV && PINECONE_INDEX) {
            retrieved = await retrieveFromPinecone(qVec);
          } else {
            retrieved = await retrieveFromFirestore(qVec);
          }
        }
      } catch (e) {
        const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
        functions.logger.error('Embedding/retrieval failed', errMsg);
        // Don't fail the whole function for retrieval errors — degrade to chat-only
        retrieved = [];
      }
    }

    // Build prompt
  const providedName = (_data?.userName || '').toString().trim();
    const nameGreeting = providedName ? `Hello ${providedName}! ` : '';
    const systemPrompt = `${nameGreeting}You are Uriel Academy's study assistant for BECE and WASSCE curriculum in Ghana. Answer in a helpful, age-appropriate way for ages 10-19. When using facts from the provided sources, cite the source id. If unsure, say you don't know and provide guidance to study topics.`;

    let userPrompt = question;
    if (retrieved && retrieved.length) {
      const contextText = retrieved.map(r => `Source ${r.id}: ${r.excerpt || ''}`).join('\n\n');
      userPrompt = `Context:\n${contextText}\n\nQuestion: ${question}\n\nAnswer concisely and cite sources by id.`;
    }

    // Call OpenAI ChatCompletion
    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ];

    let completion;
    try {
      completion = await client.chat.completions.create({
        model: 'gpt-4o-mini',
        // openai types require a more complex union type; cast to any to satisfy TS in this example
        messages: messages as any,
        max_tokens: 700,
        temperature: 0.1
      });
    } catch (e) {
      const errMsg = e instanceof Error ? `${e.name}: ${e.message}` : JSON.stringify(e);
      functions.logger.error('OpenAI completion failed', errMsg);
      throw new functions.https.HttpsError('internal', 'AI completion failed');
    }

    const reply = completion?.choices?.[0]?.message?.content || '';

    // Log conversation (best-effort)
    try {
      await admin.firestore().collection('aiChats').add({
        userId: uid,
        question,
        reply,
        retrieved: retrieved.map(r => ({ id: r.id, score: r.score })),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (e) {
      functions.logger.error('Failed to write aiChats log', e instanceof Error ? e.stack || e.message : JSON.stringify(e));
    }

    return { status: 'ok', reply, sources: retrieved };
  } catch (err) {
    // Ensure we surface a helpful error to the client and log full details
    const message = err instanceof functions.https.HttpsError ? err.message : (err instanceof Error ? err.message : JSON.stringify(err));
    functions.logger.error('aiChat error', err instanceof Error ? err.stack || err.message : JSON.stringify(err));
    // If it's already an HttpsError, rethrow; otherwise wrap
    if (err instanceof functions.https.HttpsError) throw err;
    throw new functions.https.HttpsError('internal', `AI service error: ${message}`);
  }
});

export default { aiChat };
