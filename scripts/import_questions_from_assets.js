#!/usr/bin/env node
/*
  Import question JSON files from assets/bece_rme_1999_2022 into Firestore.
  Usage:
    node scripts/import_questions_from_assets.js --dir=assets/bece_rme_1999_2022 --batch=50

  The script writes each question as a separate document under collection 'questions'.
  Optionally, if OPENAI_API_KEY is set, it will compute embeddings in small batches and write them too.
*/
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const minimist = require('minimist');

const args = minimist(process.argv.slice(2));
const dir = args.dir || path.join(__dirname, '..', 'assets', 'bece_rme_1999_2022');
const BATCH = Number(args.batch || 50);
const SLEEP_MS = Number(args.sleep || 200);

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Service account file not found at', SERVICE_ACCOUNT_PATH);
  process.exit(1);
}
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const OPENAI_KEY = process.env.OPENAI_API_KEY;
const useOpenAI = !!OPENAI_KEY;
let openaiFetch;
if (useOpenAI) {
  openaiFetch = require('node-fetch');
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function maybeEmbedDocs(docs) {
  if (!useOpenAI || docs.length === 0) return [];
  const inputs = docs.map(d => d.text);
  const resp = await openaiFetch('https://api.openai.com/v1/embeddings', {
    method: 'POST', headers: { 'Authorization': `Bearer ${OPENAI_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'text-embedding-3-small', input: inputs })
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Embedding request failed: ${resp.status} ${txt}`);
  }
  const data = await resp.json();
  return data.data.map(d => d.embedding);
}

function buildTextFromObj(obj) {
  const pieces = [];
  if (obj.questionText) pieces.push(obj.questionText);
  if (obj.options && Array.isArray(obj.options)) pieces.push(obj.options.join(' | '));
  if (obj.explanation) pieces.push(obj.explanation);
  if (obj.topic) pieces.push(obj.topic);
  if (obj.topics && Array.isArray(obj.topics)) pieces.push(obj.topics.join(' | '));
  return pieces.join('\n');
}

async function run() {
  console.log('Looking for JSON files in', dir);
  const names = fs.readdirSync(dir).filter(f => f.endsWith('_questions.json'));
  if (names.length === 0) {
    console.error('No question JSON files found in', dir);
    process.exit(1);
  }

  for (const name of names) {
    const full = path.join(dir, name);
    console.log('Processing file', full);
    const raw = fs.readFileSync(full, 'utf8');
    let parsed;
    try { parsed = JSON.parse(raw); } catch (e) { console.error('Failed to parse', full, e); continue; }

    // Support two formats: { "questions": { id: { ... } } } or an array
    let items = [];
    if (parsed.questions && typeof parsed.questions === 'object' && !Array.isArray(parsed.questions)) {
      items = Object.values(parsed.questions).map(o => ({ id: o.id || o._id || null, data: o }));
    } else if (Array.isArray(parsed)) {
      items = parsed.map(o => ({ id: o.id || o._id || null, data: o }));
    } else if (parsed && typeof parsed === 'object') {
      // maybe it's a map directly
      items = Object.values(parsed).map(o => ({ id: o.id || o._id || null, data: o }));
    }

    console.log(`Found ${items.length} questions in ${name}`);

    // Write per-doc with small sleeps to avoid write throttling.
    const toEmbed = [];
    const idToDoc = new Map();
    let processed = 0;
    for (const it of items) {
      const id = it.id || (`import_${Date.now()}_${Math.random().toString(36).slice(2,8)}`);
      const docData = it.data;
      // normalize fields
      const store = Object.assign({}, docData);
      // remove nested heavy fields if necessary
      try {
        await db.collection('questions').doc(id).set(store, { merge: true });
      } catch (e) {
        console.error('Failed writing doc', id, e.message || e);
        continue;
      }
      processed++;
      // prepare for embedding
      const text = buildTextFromObj(store) || id;
      toEmbed.push({ id, text });
      idToDoc.set(id, true);
      if (toEmbed.length >= BATCH) {
        try {
          const embs = await maybeEmbedDocs(toEmbed);
          if (embs && embs.length === toEmbed.length) {
            for (let i = 0; i < toEmbed.length; i++) {
              const d = toEmbed[i];
              await db.collection('questions').doc(d.id).update({ embedding: embs[i], embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp() });
            }
            console.log(`Embedded and wrote ${toEmbed.length} docs`);
          }
        } catch (e) {
          console.error('Embedding batch failed:', e.message || e);
        }
        toEmbed.length = 0;
        await sleep(SLEEP_MS);
      }
    }

    if (toEmbed.length > 0) {
      try {
        const embs = await maybeEmbedDocs(toEmbed);
        if (embs && embs.length === toEmbed.length) {
          for (let i = 0; i < toEmbed.length; i++) {
            const d = toEmbed[i];
            await db.collection('questions').doc(d.id).update({ embedding: embs[i], embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp() });
          }
          console.log(`Embedded and wrote ${toEmbed.length} docs`);
        }
      } catch (e) {
        console.error('Embedding final batch failed:', e.message || e);
      }
    }

    console.log(`Finished file ${name}: wrote ${processed} docs`);
  }

  console.log('Import complete');
}

run().catch(err => { console.error('Fatal', err); process.exit(1); });
