#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize admin SDK (reuse repo heuristics)
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
const assetDir = path.join(process.cwd(), 'assets', 'bece_ict');

async function batchSet() {
  console.log('Scanning ICT questions in Firestore...');
  const snap = await db.collection('questions').where('subject','==','ict').get();
  console.log('Found', snap.size, 'ICT docs');
  let updated = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const year = data.year ? String(data.year) : '';
    const qnum = data.questionNumber ? String(data.questionNumber) : '';
    if (!year || !qnum) continue;

    const candidates = [
      path.join(assetDir, `bece_ict_${year}_q_${qnum}.png`),
      path.join(assetDir, `bece_ict_${year}_q_${qnum}.svg`),
      path.join(assetDir, `bece_ict_${year}_q_${qnum}.jpg`),
      path.join(assetDir, `bece_ict_${year}_q_${qnum}.jpeg`),
      path.join(assetDir, `bece_ict_${year}_q_${qnum}.webp`),
    ];

    // Skip if imageUrl already present and non-empty
    if (data.imageUrl && String(data.imageUrl).trim().length > 0) continue;

    let chosen = null;
    for (const c of candidates) {
      if (fs.existsSync(c)) { chosen = c; break; }
    }

    if (chosen) {
      // Convert to relative asset path used by app
      const rel = path.relative(process.cwd(), chosen).replace(/\\/g, '/');
      await db.collection('questions').doc(doc.id).set({ imageUrl: rel }, { merge: true });
      updated++;
      console.log('Updated', doc.id, '->', rel);
    }
  }

  console.log('Batch complete. Documents updated:', updated);
  await admin.app().delete();
}

batchSet().catch(e => { console.error(e); process.exit(1); });
