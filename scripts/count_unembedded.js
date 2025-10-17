#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Service account file not found at', SERVICE_ACCOUNT_PATH);
  process.exit(1);
}
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('questions').get();
  let total = 0;
  let unembedded = 0;
  snapshot.forEach(doc => {
    total++;
    const d = doc.data();
    if (!d || !d.embedding || !Array.isArray(d.embedding) || d.embedding.length < 10) {
      unembedded++;
    }
  });
  console.log('Total questions:', total);
  console.log('Unembedded (no embedding or too short):', unembedded);
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
