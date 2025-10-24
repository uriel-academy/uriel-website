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
  const snapshot = await db.collection('questions').where('subject', '==', 'ict').get();
  console.log('Found', snapshot.size, 'ICT docs (filtering year locally)');
  let found = false;
  snapshot.forEach(doc => {
    const d = doc.data();
    if (d.year && String(d.year) === '2024') {
      const txt = (d.questionText || '').toString();
      const snippet = txt.length > 80 ? txt.substring(0, 80) + '...' : txt;
      console.log('-', doc.id, 'q#', d.questionNumber || '<no-num>', 'text:', snippet, 'imageUrl:', d.imageUrl || '<none>');
      if (txt.toLowerCase().includes('figure 1') || txt.toLowerCase().includes('peripheral device')) {
        console.log('  -> Likely match for Figure 1 question:', doc.id);
        found = true;
      }
    }
  });
  if (!found) console.log('No likely Figure 1 question found in ICT 2024 docs');
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
