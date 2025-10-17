import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';
import axios from 'axios';

const OPENAI_KEY = functions.config().openai?.key;
const PINECONE_KEY = functions.config().pinecone?.key;
const PINECONE_ENV = functions.config().pinecone?.env;
const PINECONE_INDEX = functions.config().pinecone?.index;

const client = new OpenAI({ apiKey: OPENAI_KEY });

// simple cosine
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
  if (!PINECONE_KEY || !PINECONE_ENV || !PINECONE_INDEX) return [];
  const url = `https://${PINECONE_INDEX}-${PINECONE_ENV}.svc.pinecone.io/query`;
  try {
    const resp = await axios.post(url, { vector: queryEmbedding, topK, includeMetadata: true }, { headers: { 'Api-Key': PINECONE_KEY, 'Content-Type': 'application/json' } });
    const matches = resp.data.matches || [];
    return matches.map((m: any) => ({ id: m.id, score: m.score, title: m.metadata?.title, excerpt: m.metadata?.text?.slice(0, 800) }));
  } catch (e) {
    console.error('Pinecone query error', e);
    return [];
  }
}

export const aiChatHttp = functions.https.onRequest((req, res) => {
  // Run the handler inside an async IIFE so the exported function returns void
  (async () => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', req.get('Origin') || '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    try {
      if (!OPENAI_KEY) {
        console.error('OpenAI key missing');
        res.status(500).json({ error: 'AI provider not configured' });
        return;
      }

      // Require authentication via Bearer ID token
      const authHeader = req.get('Authorization') || '';
      if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }
      const idToken = authHeader.split(' ')[1];
      let uid: string | null = null;
      try {
        const decoded = await admin.auth().verifyIdToken(idToken);
        uid = decoded.uid;
      } catch (e) {
        res.status(401).json({ error: 'Invalid ID token' });
        return;
      }

      const body = req.body || {};
      const question = (body.message || '').toString();
      if (!question || question.trim().length === 0) {
        res.status(400).json({ error: 'Empty message' });
        return;
      }

      // Moderation
      try {
        const mod = await client.moderations.create({ model: 'omni-moderation-latest', input: question });
        const flagged = (mod as any).results?.[0]?.flagged;
        if (flagged) { res.status(403).json({ error: 'Message flagged by moderation' }); return; }
      } catch (e) {
        console.warn('Moderation failed', e instanceof Error ? e.message : e);
      }

      const mode: 'rag' | 'chat' = body?.mode === 'chat' ? 'chat' : 'rag';
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
          console.error('Embedding/retrieval failed', e instanceof Error ? e.message : e);
          retrieved = [];
        }
      }

      const providedName = (body?.userName || '').toString().trim();
      const nameGreeting = providedName ? `Hello ${providedName}! ` : '';
      const systemPrompt = `${nameGreeting}You are Uriel Academy's study assistant for BECE and WASSCE curriculum in Ghana. Answer in a helpful, age-appropriate way for ages 10-19. When using facts from the provided sources, cite the source id. If unsure, say you don't know and provide guidance to study topics.`;

      let userPrompt = question;
      if (retrieved && retrieved.length) {
        const contextText = retrieved.map(r => `Source ${r.id}: ${r.excerpt || ''}`).join('\n\n');
        userPrompt = `Context:\n${contextText}\n\nQuestion: ${question}\n\nAnswer concisely and cite sources by id.`;
      }

      const messages = [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ];

      let completion;
      try {
        completion = await client.chat.completions.create({ model: 'gpt-4o-mini', messages: messages as any, max_tokens: 700, temperature: 0.1 });
      } catch (e) {
        console.error('OpenAI completion failed', e instanceof Error ? e.message : e);
        res.status(500).json({ error: 'AI completion failed' });
        return;
      }

      const reply = completion?.choices?.[0]?.message?.content || '';

      // Log
      try {
        await admin.firestore().collection('aiChats').add({ userId: uid, question, reply, retrieved: retrieved.map(r => ({ id: r.id, score: r.score })), createdAt: admin.firestore.FieldValue.serverTimestamp() });
      } catch (e) {
        console.error('Failed to write aiChats log', e instanceof Error ? e.message : e);
      }

      res.json({ status: 'ok', reply, sources: retrieved });
      return;
    } catch (err) {
      console.error('aiChatHttp error', err instanceof Error ? err.stack || err.message : err);
      res.status(500).json({ error: 'Internal server error' });
      return;
    }
  })();
});
