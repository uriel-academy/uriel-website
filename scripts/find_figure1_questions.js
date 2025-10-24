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
  console.log('Scanning questions collection for "figure 1" text (case-insensitive) ...');
  const snapshot = await db.collection('questions').get();
  let found = 0;
  snapshot.forEach(doc => {
    const d = doc.data();
    const txt = (d.questionText || '').toString().toLowerCase();
    if (txt.includes('figure 1') || txt.includes('figure1') || txt.includes('peripheral device')) {
      console.log('-', doc.id, 'year:', d.year, 'subject:', d.subject, 'q#:', d.questionNumber || '<no-num>');
      found++;
    }
  });
  console.log('Found total matches:', found);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
