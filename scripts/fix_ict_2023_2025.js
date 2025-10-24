#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// service account detection
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
  console.error('No service account available.');
  process.exit(1);
}

const db = admin.firestore();
const assetDir = path.join(process.cwd(), 'assets', 'bece_ict');

async function fixDocs() {
  const years = ['2023','2024','2025'];
  const snap = await db.collection('questions').where('subject','==','ict').get();
  console.log('Scanning', snap.size, 'ICT docs for years 2023-2025');
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const year = data.year && String(data.year);
    if (!years.includes(year)) continue;

    const docRef = db.collection('questions').doc(doc.id);
    const updates = {};

    // Fix options: ensure they start with letter prefixes A., B., C., D.
    if (Array.isArray(data.options) && data.options.length > 0) {
      const first = String(data.options[0] || '').trim();
      const lettered = /^[A-E]\.\s*/i.test(first);
      if (!lettered) {
        const newOptions = data.options.map((opt, idx) => {
          const letter = String.fromCharCode(65 + idx);
          const trimmed = String(opt || '').trim();
          // Avoid double-prefixing if somehow already present
          if (/^[A-E]\.\s*/i.test(trimmed)) return trimmed;
          return `${letter}. ${trimmed}`;
        });
        updates.options = newOptions;
      }
    }

    // For ICT 2024 Q38 ensure the known packaged asset is referenced
    if (year === '2024' && Number(data.questionNumber) === 38) {
      const candidate = path.join(assetDir, 'bece_ict_2024_q_38.png');
      if (fs.existsSync(candidate)) {
        updates.imageUrl = 'assets/bece_ict/bece_ict_2024_q_38.png';
      }
    }

    // If there are updates, write them back (merge)
    if (Object.keys(updates).length > 0) {
      await docRef.set(updates, { merge: true });
      updated++;
      console.log('Updated', doc.id, Object.keys(updates));
    }
  }

  console.log('Done. Documents updated:', updated);
  await admin.app().delete();
}

fixDocs().catch(e => { console.error(e); process.exit(1); });
