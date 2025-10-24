#!/usr/bin/env node
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

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
  const subject = 'ict';
  const year = '2024';
  const qnum = 38;
  const assetPath = `assets/bece_ict/bece_ict_${year}_q_${qnum}.png`;

  console.log('Searching for question doc with subject=%s, year=%s, questionNumber=%d', subject, year, qnum);

  const snapshot = await db.collection('questions')
    .where('subject', '==', subject)
    .where('year', '==', year)
    .where('questionNumber', '==', qnum)
    .limit(5)
    .get();

  if (snapshot.empty) {
    console.log('No matching question found. Listing nearby documents for inspection...');
    const nearby = await db.collection('questions')
      .where('subject', '==', subject)
      .where('year', '==', year)
      .limit(20)
      .get();
    nearby.forEach(doc => console.log(' -', doc.id, doc.data().questionNumber));
    process.exit(0);
  }

  snapshot.forEach(async (doc) => {
    const id = doc.id;
    const data = doc.data();
    console.log('Found doc:', id, 'questionNumber:', data.questionNumber, 'imageUrl:', data.imageUrl || '<none>');
    try {
      await db.collection('questions').doc(id).update({ imageUrl: assetPath, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log('Updated', id, '-> imageUrl =', assetPath);
    } catch (e) {
      console.error('Failed to update', id, e && e.message ? e.message : e);
    }
  });

  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
