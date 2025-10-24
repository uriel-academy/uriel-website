#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Find service account
const candidates = [
  path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  path.join(process.cwd(), 'serviceAccount.json'),
  path.join(__dirname, '..', 'serviceAccount.json'),
  path.join(__dirname, 'serviceAccount.json'),
];
const found = candidates.find(p => fs.existsSync(p));
if (!found) {
  console.error('No service account found. Set GOOGLE_APPLICATION_CREDENTIALS or place serviceAccount.json');
  process.exit(1);
}
const key = require(found);
admin.initializeApp({ credential: admin.credential.cert(key), projectId: key.project_id || 'uriel-academy-41fb0' });
const db = admin.firestore();

async function setSvg() {
  const docId = 'ict_2024_q38';
  const svgPath = 'assets/bece_ict/bece_ict_2024_q_38.svg';
  console.log('Updating', docId, '->', svgPath);
  const ref = db.collection('questions').doc(docId);
  await ref.set({ imageUrl: svgPath }, { merge: true });
  console.log('Updated Firestore doc', docId);
  await admin.app().delete();
}

setSvg().catch(e => { console.error(e); process.exit(1); });
