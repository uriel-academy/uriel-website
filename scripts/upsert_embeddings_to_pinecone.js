#!/usr/bin/env node
/*
  Reads question docs from Firestore that have an `embedding` field and upserts them to a Pinecone index.
  Requires environment variables:
    PINECONE_API_KEY, PINECONE_ENV, PINECONE_INDEX

  Usage:
    $env:PINECONE_API_KEY='...' ; $env:PINECONE_ENV='us-west1-gcp' ; $env:PINECONE_INDEX='uriel-index'
    node scripts/upsert_embeddings_to_pinecone.js --batch=100
*/
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const minimist = require('minimist');

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Service account file not found at', SERVICE_ACCOUNT_PATH);
  process.exit(1);
}
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const args = minimist(process.argv.slice(2));
const BATCH = Number(args.batch || 100);

const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const PINECONE_ENV = process.env.PINECONE_ENV; // e.g. us-west1-gcp
const PINECONE_INDEX = process.env.PINECONE_INDEX;

if (!PINECONE_API_KEY || !PINECONE_ENV || !PINECONE_INDEX) {
  console.error('Please set PINECONE_API_KEY, PINECONE_ENV, and PINECONE_INDEX environment variables');
  process.exit(1);
}

async function upsertBatch(items) {
  const url = `https://${PINECONE_INDEX}-${PINECONE_ENV}.svc.pinecone.io/vectors/upsert`;
  const body = { vectors: items.map(it => ({ id: it.id, values: it.embedding, metadata: it.metadata || {} })) };
  const resp = await fetch(url, { method: 'POST', headers: { 'Api-Key': PINECONE_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Pinecone upsert failed: ${resp.status} ${txt}`);
  }
  return true;
}

async function run() {
  console.log('Gathering question docs with embeddings from Firestore...');
  const q = db.collection('questions').where('embedding', '!=', null).select('embedding','subject','examType','year','questionNumber');
  const snapshot = await q.get();
  if (snapshot.empty) { console.log('No embedded docs found'); return; }
  console.log('Found', snapshot.size, 'embedded docs');

  const items = [];
  snapshot.forEach(doc => {
    const d = doc.data();
    if (d.embedding && Array.isArray(d.embedding) && d.embedding.length > 10) {
      items.push({ id: doc.id, embedding: d.embedding, metadata: { subject: d.subject, examType: d.examType, year: d.year, qnum: d.questionNumber } });
    }
  });

  console.log('Preparing to upsert', items.length, 'vectors to Pinecone in batches of', BATCH);
  for (let i = 0; i < items.length; i += BATCH) {
    const chunk = items.slice(i, i + BATCH);
    try {
      await upsertBatch(chunk);
      console.log(`Upserted ${chunk.length} vectors (${i + chunk.length}/${items.length})`);
    } catch (e) {
      console.error('Upsert failed for chunk starting at', i, e.message || e);
    }
    await new Promise(r => setTimeout(r, 300));
  }

  console.log('Pinecone upsert complete');
}

run().catch(err => { console.error('Fatal', err); process.exit(1); });
