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
  const year = 2024;
  const qnum = 38;
  const qFile = path.join(__dirname, '..', 'assets', 'bece_ict', `ict_${year}_questions.json`);
  const aFile = path.join(__dirname, '..', 'assets', 'bece_ict', `ict_${year}_answers.json`);
  if (!fs.existsSync(qFile) || !fs.existsSync(aFile)) {
    console.error('Missing asset files:', qFile, aFile);
    process.exit(1);
  }
  const qObj = JSON.parse(fs.readFileSync(qFile, 'utf8'));
  const aObj = JSON.parse(fs.readFileSync(aFile, 'utf8'));
  const mc = qObj.multiple_choice || {};
  const amc = aObj.multiple_choice || {};
  const key = `q${qnum}`;
  const qdata = mc[key];
  if (!qdata) { console.error('Question not found in asset for', key); process.exit(1); }
  const ansRaw = amc[key];

  const options = qdata.possibleAnswers || qdata.possible_answers || [];
  // resolve correctAnswer text
  let correctAnswer = null;
  if (typeof ansRaw === 'string') {
    const m = ansRaw.trim().match(/^([A-E])\b/i);
    if (m) {
      const letter = m[1].toUpperCase();
      // find option starting with that letter
      const foundOpt = options.find(o => (o.trim().toUpperCase().startsWith(letter + '.') || o.trim().toUpperCase().startsWith(letter + ' ')) );
      correctAnswer = foundOpt || (options[letter.charCodeAt(0)-65] || null);
    } else if (/^[A-E]$/.test(ansRaw.trim())) {
      const letter = ansRaw.trim();
      const foundOpt = options.find(o => (o.trim().toUpperCase().startsWith(letter + '.') || o.trim().toUpperCase().startsWith(letter + ' ')) );
      correctAnswer = foundOpt || (options[letter.charCodeAt(0)-65] || null);
    } else {
      // maybe full option text
      const foundOpt = options.find(o => o.toLowerCase().includes(ansRaw.toLowerCase()));
      correctAnswer = foundOpt || ansRaw;
    }
  }

  const docId = `ict_${year}_q${qnum}`;
  const doc = {
    id: docId,
    questionText: qdata.question || qdata.questionText || '',
    type: 'multipleChoice',
    subject: 'ict',
    subjectName: 'Information and Communication Technology',
    subjectCode: 'ICT',
    examType: 'bece',
    examName: 'Basic Education Certificate Examination',
    year: String(year),
    section: 'A',
    questionNumber: qnum,
    options: options.map(o => o.replace(/^\s*[A-E]\.\s*/i, '').trim()),
    correctAnswer: correctAnswer || null,
    explanation: `BECE ${year} ICT Question ${qnum}`,
    marks: 1,
    difficulty: 'medium',
    topics: ['ICT', 'BECE', String(year)],
    tags: ['ict', 'bece', String(year), 'past-question'],
    createdBy: 'bulk_import_script',
    isActive: true,
    isPremium: false,
    metadata: {
      source: `BECE ${year} ICT`,
      importDate: new Date().toISOString(),
      verified: true,
      version: '2.0'
    },
    imageUrl: `assets/bece_ict/bece_ict_${year}_q_${qnum}.png`,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  try {
    await db.collection('questions').doc(docId).set(doc, { merge: true });
    console.log('Wrote question doc', docId);
  } catch (e) {
    console.error('Failed to write doc', e && e.message ? e.message : e);
    process.exit(1);
  }

  process.exit(0);
})();
