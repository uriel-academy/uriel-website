const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// init admin with service account fallback
let initialized = false;
if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  initialized = true;
} else {
  const candidates = [
    path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
    path.join(process.cwd(), 'serviceAccount.json'),
    path.join(__dirname, '..', 'serviceAccount.json'),
    path.join(__dirname, 'serviceAccount.json'),
  ];
  const found = candidates.find(p => fs.existsSync(p));
  if (found) {
    const key = require(found);
    admin.initializeApp({ credential: admin.credential.cert(key) });
    initialized = true;
    console.log('Initialized admin SDK using service account file:', found);
  }
}
if (!initialized) {
  console.error('No service account available.');
  process.exit(1);
}

const db = admin.firestore();
const assetsDir = path.join(process.cwd(), 'assets', 'bece_ict', 'bece_ict_answers_fulltext_2011_2022');

(async () => {
  const years = [];
  for (let y = 2011; y <= 2022; y++) years.push(y);
  let mismatches = [];
  for (const y of years) {
    const aPath = path.join(assetsDir, `bece_ict_${y}_answers_fulltext.json`);
    if (!fs.existsSync(aPath)) {
      console.warn(`Combined answer file missing for ${y}: ${aPath}`);
      continue;
    }
    const aObj = JSON.parse(fs.readFileSync(aPath, 'utf8'));
    const mc = aObj.multiple_choice || {};
    for (let i = 1; i <= 40; i++) {
      const qKey = `q${i}`;
      const expectedFullRaw = (mc[qKey]) || null;
      const expectedFull = expectedFullRaw ? String(expectedFullRaw).trim() : null;
      const expectedLetter = expectedFull ? String(expectedFull).charAt(0).toUpperCase() : null;
      const docId = `ict_${y}_q${i}`;
      const doc = await db.collection('questions').doc(docId).get();
      if (!doc.exists) {
        mismatches.push({ doc: docId, reason: 'missing_doc' });
        continue;
      }
      const data = doc.data();
      const actualFull = data.fullAnswer ? String(data.fullAnswer).trim() : null;
      const actualLetter = data.correctAnswer ? String(data.correctAnswer).trim().toUpperCase() : null;
      // Normalize spacing/punctuation before compare
      const normalize = s => (s || '').replace(/\s+/g, ' ').trim();
      if (normalize(expectedFull) !== normalize(actualFull) || expectedLetter !== actualLetter) {
        mismatches.push({ doc: docId, expected: { letter: expectedLetter, full: expectedFull }, actual: { letter: actualLetter, full: actualFull } });
      }
    }
  }

  if (!mismatches.length) {
    console.log('All question docs match the combined fulltext answer files.');
  } else {
    console.log('Found mismatches or missing docs:');
    mismatches.slice(0, 200).forEach(m => console.log(JSON.stringify(m)));
    console.log(`Total mismatches/missing: ${mismatches.length}`);
  }
  process.exit(0);
})().catch(err => { console.error(err); process.exit(1); });
