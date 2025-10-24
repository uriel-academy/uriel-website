#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// service account detection
const candidates = [
  path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  path.join(process.cwd(), 'serviceAccount.json'),
  path.join(__dirname, '..', 'serviceAccount.json'),
  path.join(__dirname, 'serviceAccount.json'),
];
const found = candidates.find(p => fs.existsSync(p));
if (!found) {
  console.error('No service account found. Aborting.');
  process.exit(1);
}
const key = require(found);
admin.initializeApp({ credential: admin.credential.cert(key), projectId: key.project_id || 'uriel-academy-41fb0' });
const db = admin.firestore();

async function setJpeg() {
  const docId = 'ict_2024_q38';
  // Accept jpeg OR jpg OR png (the user may have used .jpg)
  const candidates = [
    'assets/bece_ict/bece_ict_2024_q_38.jpeg',
    'assets/bece_ict/bece_ict_2024_q_38.jpg',
    'assets/bece_ict/bece_ict_2024_q_38.png',
  ];

  let chosen = null;
  for (const rel of candidates) {
    const full = path.join(process.cwd(), rel);
    if (fs.existsSync(full)) { chosen = rel; break; }
  }

  if (!chosen) {
    console.error('No image found for ICT 2024 Q38 in assets; looked for', candidates.join(', '));
    process.exit(1);
  }

  console.log('Setting', docId, 'imageUrl ->', chosen);
  await db.collection('questions').doc(docId).set({ imageUrl: chosen }, { merge: true });
  console.log('Updated Firestore doc', docId);
  await admin.app().delete();
}

setJpeg().catch(e => { console.error(e); process.exit(1); });
