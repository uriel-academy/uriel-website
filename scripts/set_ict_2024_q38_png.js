#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// service account detection (same heuristic used elsewhere in repo)
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
  admin.initializeApp({ credential: admin.credential.cert(key), projectId: key.project_id || 'uriel-academy-41fb0' });
  initialized = true;
  console.log('Initialized admin SDK using', found);
}
if (!initialized && process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  initialized = true;
  console.log('Initialized admin SDK using application default credentials');
}
if (!initialized) {
  console.error('No service account available. Aborting.');
  process.exit(1);
}

const db = admin.firestore();

async function setPng() {
  const docId = 'ict_2024_q38';
  const pngPath = 'assets/bece_ict/bece_ict_2024_q_38.png';

  // Confirm PNG exists locally
  const fullPng = path.join(process.cwd(), pngPath);
  if (!fs.existsSync(fullPng)) {
    console.error('PNG not found at', fullPng);
    process.exit(1);
  }

  console.log('Updating Firestore doc', docId, 'imageUrl ->', pngPath);
  const ref = db.collection('questions').doc(docId);
  await ref.set({ imageUrl: pngPath }, { merge: true });
  console.log('Updated', docId);

  await admin.app().delete();
}

setPng().catch(e => { console.error(e); process.exit(1); });
