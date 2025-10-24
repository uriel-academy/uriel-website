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
  console.log('Scanning questions collection for docs with year==2024 and subject containing "ict" (case-insensitive).');
  const snapshot = await db.collection('questions').get();
  let matches = 0;
  snapshot.forEach(doc => {
    const d = doc.data();
    if (!d) return;
    const year = d.year ? String(d.year) : '';
    const subj = d.subject ? String(d.subject).toLowerCase() : '';
    if (year === '2024' && subj.includes('ict')) {
      matches++;
      if (matches <= 50) {
        console.log('-', doc.id, 'subject:', d.subject, 'q#', d.questionNumber || '<no-num>', 'imageUrl:', d.imageUrl || '<none>');
      }
    }
  });
  console.log('Total matches:', matches);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
