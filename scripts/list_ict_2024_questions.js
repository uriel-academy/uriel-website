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
  const subj = 'ict';
  const yearStr = '2024';
  const yearNum = 2024;

  console.log('Looking for ICT questions for year (string) %s', yearStr);
  const snap1 = await db.collection('questions').where('subject', '==', subj).where('year', '==', yearStr).get();
  console.log('Found (year as string):', snap1.size);
  snap1.forEach(d => console.log('-', d.id, 'q#', d.data().questionNumber, 'imageUrl:', d.data().imageUrl));

  console.log('\nLooking for ICT questions for year (number) %d', yearNum);
  const snap2 = await db.collection('questions').where('subject', '==', subj).where('year', '==', yearNum).get();
  console.log('Found (year as number):', snap2.size);
  snap2.forEach(d => console.log('-', d.id, 'q#', d.data().questionNumber, 'imageUrl:', d.data().imageUrl));

  console.log('\nListing first 40 ICT docs regardless of year:');
  const snap3 = await db.collection('questions').where('subject', '==', subj).limit(40).get();
  console.log('Found total (first 40):', snap3.size);
  snap3.forEach(d => console.log('-', d.id, 'year:', d.data().year, 'q#', d.data().questionNumber, 'imageUrl:', d.data().imageUrl));

  process.exit(0);
})();
