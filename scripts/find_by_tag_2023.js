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
  const byTag = await db.collection('questions').where('tags', 'array-contains', '2023').get();
  console.log('Found by tags 2023:', byTag.size);
  byTag.forEach(doc => console.log(' -', doc.id, doc.data().year, doc.data().subject, doc.data().examType));

  const byTopics = await db.collection('questions').where('topics', 'array-contains', '2023').get();
  console.log('Found by topics 2023:', byTopics.size);
  byTopics.forEach(doc => console.log(' -', doc.id, doc.data().year, doc.data().subject, doc.data().examType));

  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
