#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// try to find a local service account like other scripts do
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
  console.log('Initialized admin SDK using', found);
  initialized = true;
}
if (!initialized && process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  console.log('Initialized admin SDK using application default credentials');
  initialized = true;
}
if (!initialized) {
  console.error('No service account available. Set GOOGLE_APPLICATION_CREDENTIALS or place a service account file in the repo.');
  process.exit(1);
}

const db = admin.firestore();
const assetsDir = path.join(__dirname, '..', 'assets', 'bece_ict');
const years = [2023, 2024, 2025];

async function processYear(year) {
  const qFile = path.join(assetsDir, `ict_${year}_questions.json`);
  const aFile = path.join(assetsDir, `ict_${year}_answers.json`);
  if (!fs.existsSync(qFile)) {
    console.warn(`Skipping ${year}: missing questions file (${qFile})`);
    return { inserted: 0, skipped: 0, total: 0 };
  }

  const qRaw = JSON.parse(fs.readFileSync(qFile, 'utf8'));
  const aRaw = fs.existsSync(aFile) ? JSON.parse(fs.readFileSync(aFile, 'utf8')) : {};

  // Normalize to a map like { q1: {question, possibleAnswers}} or array
  let questionsMap = {};
  if (qRaw && qRaw.multiple_choice) {
    questionsMap = qRaw.multiple_choice;
  } else if (Array.isArray(qRaw)) {
    qRaw.forEach((q, idx) => { questionsMap[`q${idx+1}`] = { question: q.question || q.questionText || q.q, possibleAnswers: q.possibleAnswers || q.options || [] }; });
  } else {
    questionsMap = qRaw;
  }

  const answersMap = aRaw && (aRaw.multiple_choice || aRaw);

  let inserted = 0, skipped = 0, total = 0;

  for (const key of Object.keys(questionsMap)) {
    total++;
    const num = parseInt(key.replace(/[^0-9]/g, ''), 10) || total;
    const q = questionsMap[key];
    const ans = answersMap ? (answersMap[key] || answersMap[key.toLowerCase()] || null) : null;

    const questionText = (q.question || q.questionText || q.q || '').toString();
    const options = q.possibleAnswers || q.options || q.choices || [];
    let correct = null;
    let fullAnswer = null;
    if (ans) {
      if (typeof ans === 'string') {
        fullAnswer = ans;
        const m = ans.match(/^([A-E])\b|^([A-E])\./i);
        if (m) correct = (m[1] || m[2]).toUpperCase();
        if (!correct) correct = ans.trim().charAt(0).toUpperCase();
      } else if (typeof ans === 'object') {
        fullAnswer = JSON.stringify(ans);
        correct = ans.answer || ans.correct || null;
      }
    }

    const docId = `ict_${year}_q${num}`;
    try {
      const ref = db.collection('questions').doc(docId);
      const snap = await ref.get();
      if (snap.exists) {
        skipped++;
        continue;
      }

      const now = new Date().toISOString();
      const doc = {
        id: docId,
        questionText: questionText,
        type: 'multipleChoice',
        subject: 'ict',
        examType: 'bece',
        year: year.toString(),
        section: 'A',
        questionNumber: num,
        options: options.map(o => (typeof o === 'string' ? o.replace(/^\s*[A-E]\.\s*/i, '').trim() : o)),
        correctAnswer: correct || (fullAnswer ? fullAnswer.split('.')[0] : null),
        fullAnswer: fullAnswer || null,
        explanation: `Imported from BECE ${year} ICT`,
        marks: 1,
        difficulty: 'medium',
        topics: ['ICT','BECE', year.toString()],
        createdAt: now,
        updatedAt: now,
        createdBy: 'bulk_import_script',
        isActive: true,
        metadata: { source: `BECE ${year} ICT`, importDate: now, verified: true, timestamp: Date.now() }
      };

      await ref.set(doc);
      inserted++;
    } catch (e) {
      console.error('Error importing', docId, e && e.message ? e.message : e);
    }
  }

  return { inserted, skipped, total };
}

(async () => {
  let totalInserted = 0, totalSkipped = 0, totalCount = 0;
  for (const y of years) {
    const res = await processYear(y);
    console.log(`Year ${y}: inserted=${res.inserted}, skipped=${res.skipped}, total=${res.total}`);
    totalInserted += res.inserted;
    totalSkipped += res.skipped;
    totalCount += res.total;
  }

  console.log('Done. Summary:');
  console.log('Total expected from assets (2023-2025):', totalCount);
  console.log('Inserted now:', totalInserted);
  console.log('Already existed/skipped:', totalSkipped);

  const snap = await db.collection('questions').where('subject','==','ict').get();
  console.log('Firestore ICT total now:', snap.size);
  await admin.app().delete();
  process.exit(0);
})();
