#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let initialized = false;
const candidates = [
  path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  path.join(process.cwd(), 'serviceAccount.json'),
  path.join(__dirname, '..', 'serviceAccount.json'),
  path.join(__dirname, 'serviceAccount.json'),
];
const found = candidates.find(p => fs.existsSync(p));
if (found) {
  const key = require(found);
  admin.initializeApp({ credential: admin.credential.cert(key), projectId: key.project_id });
  initialized = true;
}
if (!initialized && process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  initialized = true;
}
if (!initialized) { console.error('No service account available.'); process.exit(1); }
const db = admin.firestore();

(async () => {
  console.log('Querying questions where subject=="ict" and year=="2024" and questionNumber==38');
  const snapshot = await db.collection('questions').where('subject', '==', 'ict').get();
  let matches = [];
  snapshot.forEach(doc => {
    const d = doc.data();
    if (d.year && String(d.year) === '2024' && Number(d.questionNumber) === 38) {
      matches.push({ id: doc.id, data: d });
    }
  });
  if (matches.length === 0) {
    console.log('No documents found with questionNumber 38 for ICT 2024');
  } else {
    console.log('Found', matches.length, 'matching docs:');
    matches.forEach(m => {
      const txt = (m.data.questionText || '').toString();
      const snippet = txt.length > 200 ? txt.substring(0, 200) + '...' : txt;
      console.log('-', m.id, 'imageUrl:', m.data.imageUrl || '<none>');
      console.log('  questionText:', snippet);
    });
  }
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
