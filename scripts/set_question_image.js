#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const minimist = require('minimist');

const args = minimist(process.argv.slice(2));
const id = args.id;
const imageUrl = args.image || args.url;
if (!id || !imageUrl) {
  console.error('Usage: node set_question_image.js --id=<docId> --image=<imagePathOrUrl>');
  process.exit(1);
}

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
  const docRef = db.collection('questions').doc(id);
  const doc = await docRef.get();
  if (!doc.exists) {
    console.error('Document not found:', id);
    process.exit(1);
  }
  await docRef.update({ imageUrl, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  console.log('Updated', id, 'imageUrl ->', imageUrl);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
