import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';

// Use admin.firestore() inside the function to avoid init ordering issues
const OPENAI_KEY = functions.config().openai?.key;
const client = new OpenAI({ apiKey: OPENAI_KEY });

// Ingest up to `limit` question docs missing embeddings and compute embeddings.
export const ingestDocs = functions.https.onCall(async (data, context) => {
  // Require admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can run ingestion');
  }

  const limit = Number(data?.limit || 200);
  const snapshot = await admin.firestore().collection('questions').limit(limit).get();
  const toProcess: Array<{ id: string; text: string }> = [];

  snapshot.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => {
    const d: any = doc.data();
    if (!d) return;
    if (d.embedding && Array.isArray(d.embedding) && d.embedding.length > 10) return; // already embedded
    // Build text from question fields
    const pieces: string[] = [];
    if (d.questionText) pieces.push(d.questionText);
    if (d.options && Array.isArray(d.options)) pieces.push(d.options.join(' | '));
    if (d.explanation) pieces.push(d.explanation);
    const text = pieces.join('\n');
    toProcess.push({ id: doc.id, text });
  });

  if (toProcess.length === 0) {
    return { status: 'ok', message: 'No docs to ingest' };
  }

  const results: Array<{ id: string; success: boolean; error?: string }> = [];

  for (const item of toProcess) {
    try {
      const embResp = await client.embeddings.create({ model: 'text-embedding-3-small', input: item.text });
      const vector = embResp.data?.[0]?.embedding as number[] | undefined;
      if (!vector) {
        results.push({ id: item.id, success: false, error: 'No vector returned' });
        continue;
      }
  await admin.firestore().collection('questions').doc(item.id).update({ embedding: vector, embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp() });
      results.push({ id: item.id, success: true });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      results.push({ id: item.id, success: false, error: errMsg });
    }
    // light delay to avoid throttling
    await new Promise(r => setTimeout(r, 200));
  }

  return { status: 'ok', processed: results.length, results };
});

export default { ingestDocs };
