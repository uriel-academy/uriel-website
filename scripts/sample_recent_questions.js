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
  // fetch most recently created questions (limit 50)
  const snapshot = await db.collection('questions').orderBy('createdAt', 'desc').limit(50).get();
  console.log('Found', snapshot.size, 'recent docs');
  snapshot.forEach(doc => {
    const d = doc.data();
    console.log('--- doc id:', doc.id, 'year:', d.year, 'subject:', d.subject, 'examType:', d.examType, 'createdBy:', d.createdBy);
  });
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
