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
  const year = '2023';
  const id = `rme_${year}_q1`;
  // Check if already exists
  const doc = await db.collection('questions').doc(id).get();
  if (doc.exists) {
    console.log(id, 'already exists — nothing to do');
    process.exit(0);
  }
  // Try to find answer letter from answers asset
  const aPath = path.join(__dirname, '..', 'assets', 'bece_rme_1999_2022', `bece_${year}_answers.json`);
  let answerLetter = null;
  if (fs.existsSync(aPath)) {
    const aRaw = JSON.parse(fs.readFileSync(aPath, 'utf8'));
    const aMap = aRaw.multiple_choice || aRaw.multipleChoice || {};
    const aVal = aMap['q1'];
    if (typeof aVal === 'string') {
      const m = aVal.trim().match(/^([A-E])\b/i);
      if (m) answerLetter = m[1].toUpperCase();
      else if (/^[A-E]$/.test(aVal.trim())) answerLetter = aVal.trim().toUpperCase();
    }
  }

  const placeholder = {
    id,
    questionText: 'MISSING: Question 1 was not present in the source asset; this is a placeholder.',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    subjectName: 'Religious And Moral Education',
    subjectCode: 'RME',
    examType: 'bece',
    examName: 'Basic Education Certificate Examination',
    year: String(year),
    section: 'A',
    questionNumber: 1,
    options: [],
    correctAnswer: null,
    answerLetter: answerLetter || null,
    explanation: null,
    marks: 1,
    difficulty: 'medium',
    topics: ['Religious And Moral Education', 'BECE', String(year)],
    tags: ['rme', 'bece', String(year), 'past-question', 'placeholder'],
    createdBy: 'bulk_import_script',
    isActive: false,
    isPremium: false,
    metadata: {
      source: `BECE ${year} RME (placeholder)`,
      importDate: new Date().toISOString(),
      verified: false,
      version: '2.0'
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('questions').doc(id).set(placeholder);
  console.log('Wrote placeholder doc', id, 'answerLetter:', answerLetter);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
