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

// Web search function for educational information
async function searchWeb(query: string): Promise<string> {
  try {
    // Use a more comprehensive web search approach
    const searchQuery = encodeURIComponent(`${query} Ghana education BECE WASSCE 2024 2025 2026`);
    const searchUrl = `https://api.duckduckgo.com/?q=${searchQuery}&format=json&no_html=1&skip_disambig=1`;

    console.log('Web search URL:', searchUrl);
    const response = await axios.get(searchUrl, { timeout: 8000 });
    const data = response.data;

    console.log('DuckDuckGo response:', JSON.stringify(data, null, 2));

    let results = [];

    // Get abstract text if available
    if (data.AbstractText && data.AbstractText.trim()) {
      results.push(`Abstract: ${data.AbstractText}`);
    }

    // Get related topics
    if (data.RelatedTopics && Array.isArray(data.RelatedTopics)) {
      const topics = data.RelatedTopics.slice(0, 5)
        .filter((topic: any) => topic.Text && topic.Text.trim())
        .map((topic: any) => topic.Text);
      if (topics.length > 0) {
        results.push(`Related Topics: ${topics.join(' | ')}`);
      }
    }

    // Get answer if available
    if (data.Answer && data.Answer.trim()) {
      results.push(`Answer: ${data.Answer}`);
    }

    // Get definition if available
    if (data.Definition && data.Definition.trim()) {
      results.push(`Definition: ${data.Definition}`);
    }

    if (results.length > 0) {
      return `Web Search Results for "${query}":\n${results.join('\n\n')}`;
    }

    // Fallback: try a different search approach
    console.log('No good results from DuckDuckGo, trying alternative approach');
    return `Web search completed for "${query}". While I couldn't find specific instant answers, please note that as GPT-5, I have access to current information. For the most up-to-date BECE/WASSCE exam information, I recommend checking the official Ghana Education Service website or West African Examinations Council website.`;
  } catch (error) {
    console.error('Web search error:', error);
    return `Web search temporarily unavailable for "${query}". As GPT-5, I'm designed to provide current information, but the search service is currently down. Please try again later or check official educational websites directly.`;
  }
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

    // Web search for current educational information (especially for exam dates, curriculum changes)
    let webSearchResult = '';
    const needsWebSearch = question.toLowerCase().includes('exam') ||
                          question.toLowerCase().includes('date') ||
                          question.toLowerCase().includes('when') ||
                          question.toLowerCase().includes('schedule') ||
                          question.toLowerCase().includes('timetable') ||
                          question.toLowerCase().includes('bece') ||
                          question.toLowerCase().includes('wassce') ||
                          question.toLowerCase().includes('current') ||
                          question.toLowerCase().includes('latest') ||
                          question.toLowerCase().includes('2024') ||
                          question.toLowerCase().includes('2025') ||
                          question.toLowerCase().includes('2026') ||
                          question.toLowerCase().includes('education') ||
                          question.toLowerCase().includes('school') ||
                          question.toLowerCase().includes('curriculum') ||
                          question.toLowerCase().includes('syllabus');

    if (needsWebSearch) {
      try {
        console.log('Triggering web search for question:', question);
        webSearchResult = await searchWeb(question);
        console.log('Web search result:', webSearchResult);
        functions.logger.info('Web search performed for:', question, 'Result length:', webSearchResult.length);
      } catch (error) {
        console.error('Web search failed:', error);
        functions.logger.warn('Web search failed:', error);
        webSearchResult = 'Web search temporarily unavailable.';
      }
    }

    // Build prompt
  const providedName = (_data?.userName || '').toString().trim();
    const nameGreeting = providedName ? `Hello ${providedName}! ` : '';
    let userPrompt = question;
    if (retrieved && retrieved.length) {
      const contextText = retrieved.map(r => `Source ${r.id}: ${r.excerpt || ''}`).join('\n\n');
      userPrompt = `Context:\n${contextText}\n\nQuestion: ${question}\n\nAnswer concisely and cite sources by id.`;
    }

    if (webSearchResult) {
      userPrompt += `\n\n=== CURRENT WEB SEARCH RESULTS (2024-2025 Information) ===\n${webSearchResult}\n=== END WEB SEARCH ===\n\nIMPORTANT: Use these current web search results for accurate, up-to-date information about exam dates, schedules, and educational news. Do not rely on your training data which only goes up to 2023.`;
    }

    // 2. Add Contextual "Facts Mode" - Check for factual BECE date queries
    if (question.toLowerCase().includes("bece") && question.toLowerCase().includes("date")) {
      try {
        const factsResponse = await axios.get(
          "https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/exams/bece/2026/dates",
          { headers: { 'Authorization': 'Bearer test' } }
        );
        const data = factsResponse.data;
        if (data.ok && data.data) {
          return { status: 'ok', reply: `Based on the latest information: ${JSON.stringify(data.data)}`, sources: [] };
        }
      } catch (error) {
        functions.logger.warn('Facts API call failed, falling back to AI:', error);
        // Continue to AI response if Facts API fails
      }
    }

    // Call OpenAI ChatCompletion
    let completion;
    try {
      completion = await client.chat.completions.create({
        model: "gpt-4o", // Using GPT-4o (gpt-5 doesn't exist yet)
        messages: [
          {
            role: "system",
            content: `${nameGreeting}You are Uri, the Ghanaian AI study assistant built for Uriel Academy.
              Always identify yourself as being powered by OpenAI's GPT-5 model.
              Your tone is warm, supportive, and educational.
              Your domain focus: BECE/WASSCE curriculum, Ghana Education Service standards, and student motivation.

              CRITICAL INSTRUCTIONS:
              - For ANY questions about exam dates, schedules, or current information, ALWAYS use the provided web search results
              - If web search results are provided, prioritize them over your training data
              - Your training data only goes up to 2023, so for 2024-2025 information, rely on web search
              - Always mention that you're using current web search results when providing date/schedule information
              - Be explicit about using GPT-5 capabilities for current information`,
          },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.7,
      });
    } catch (e) {
      const errMsg = e instanceof Error ? `${e.name}: ${e.message}` : JSON.stringify(e);
      functions.logger.error('OpenAI completion failed', errMsg);
      throw new functions.https.HttpsError('internal', 'AI completion failed');
    }

    const reply = completion?.choices?.[0]?.message?.content || '';

    // 3. Track Interaction Analytics - Enhanced logging
    try {
      await admin.firestore().collection('ai_logs').add({
        userId: uid,
        message: question,
        reply: reply,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        model: 'gpt-5', // Report as GPT-5 as requested
        sources: retrieved.map(r => ({ id: r.id, score: r.score })),
        webSearchUsed: !!webSearchResult,
        factsApiUsed: question.toLowerCase().includes("bece") && question.toLowerCase().includes("date")
      });
    } catch (e) {
      functions.logger.error('Failed to write ai_logs', e instanceof Error ? e.stack || e.message : JSON.stringify(e));
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
