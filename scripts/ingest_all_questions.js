#!/usr/bin/env node
/*
  Batch ingest questions: compute OpenAI embeddings for Firestore 'questions' collection
  Usage:
    set OPENAI_API_KEY=sk-... (Windows PowerShell: $env:OPENAI_API_KEY="sk-...")
    node scripts/ingest_all_questions.js --batch=100 --pageSize=500

  This script uses the service account JSON available in the repo at
  ./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json
*/
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const fetch = global.fetch || require('node-fetch');

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Service account file not found at', SERVICE_ACCOUNT_PATH);
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const OPENAI_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_KEY) {
  console.error('Please set OPENAI_API_KEY environment variable');
  process.exit(1);
}

const argv = require('minimist')(process.argv.slice(2));
const BATCH = Number(argv.batch || 100); // how many embeddings per OpenAI request
const PAGE_SIZE = Number(argv.pageSize || 500); // how many documents to page from Firestore
const SLEEP_MS = Number(argv.sleep || 200);

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function buildText(doc) {
  const pieces = [];
  if (doc.questionText) pieces.push(String(doc.questionText));
  if (doc.options && Array.isArray(doc.options)) pieces.push(doc.options.join(' | '));
  if (doc.explanation) pieces.push(String(doc.explanation));
  if (doc.topic) pieces.push(String(doc.topic));
  return pieces.join('\n');
}

async function embedBatch(inputs) {
  const url = 'https://api.openai.com/v1/embeddings';
  const body = { model: 'text-embedding-3-small', input: inputs };
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${OPENAI_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`OpenAI embedding request failed: ${resp.status} ${txt}`);
  }
  const data = await resp.json();
  return data.data.map(d => d.embedding);
}

async function run() {
  console.log('Starting ingestion. Batch size:', BATCH, 'page size:', PAGE_SIZE);
  let lastDoc = null;
  let totalProcessed = 0;
  while (true) {
    let q = db.collection('questions').orderBy('__name__').limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    const docsToEmbed = [];
    snap.forEach(doc => {
      const d = doc.data();
      if (!d) return;
      if (!d.embedding || !Array.isArray(d.embedding) || d.embedding.length < 10) {
        const text = buildText(d) || (`${doc.id}`);
        docsToEmbed.push({ id: doc.id, text });
      }
    });

    if (docsToEmbed.length === 0) {
      lastDoc = snap.docs[snap.docs.length - 1];
      console.log('Page had no docs to embed; continuing to next page...');
      continue;
    }

    console.log(`Processing page with ${docsToEmbed.length} docs to embed`);
    for (let i = 0; i < docsToEmbed.length; i += BATCH) {
      const chunk = docsToEmbed.slice(i, i + BATCH);
      const inputs = chunk.map(c => c.text);
      try {
        const vectors = await embedBatch(inputs);
        // write back
        const batch = db.batch();
        for (let j = 0; j < vectors.length; j++) {
          const id = chunk[j].id;
          const v = vectors[j];
          const ref = db.collection('questions').doc(id);
          batch.update(ref, { embedding: v, embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        await batch.commit();
        totalProcessed += vectors.length;
        console.log(`Wrote ${vectors.length} embeddings (total ${totalProcessed})`);
      } catch (err) {
        console.error('Embedding batch failed:', err.message || err);
      }
      await sleep(SLEEP_MS);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    // small delay between pages
    await sleep(500);
  }

  console.log('Ingestion complete. Total processed:', totalProcessed);
  process.exit(0);
}

run().catch(err => { console.error('Fatal error', err); process.exit(1); });
