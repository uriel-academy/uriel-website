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
  console.log('Scanning up to 5000 docs for doc.id or subject containing "ict"');
  const snapshot = await db.collection('questions').limit(5000).get();
  let matches = 0;
  snapshot.forEach(doc => {
    const d = doc.data() || {};
    const idLower = String(doc.id).toLowerCase();
    const subj = d.subject ? String(d.subject).toLowerCase() : '';
    if (idLower.includes('ict') || subj.includes('ict')) {
      matches++;
      if (matches <= 200) console.log('-', doc.id, 'subject:', d.subject, 'year:', d.year, 'q#', d.questionNumber || '<no-num>');
    }
  });
  console.log('Total matches:', matches);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
