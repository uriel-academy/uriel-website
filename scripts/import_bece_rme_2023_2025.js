#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// init admin
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

function normalizeQuestionText(q) {
  if (!q) return q;
  // remove leading numbering like "2. " or "10. "
  return q.replace(/^\s*\d+\.\s*/, '').trim();
}

function findOptionByLetter(options, letter) {
  if (!options || !letter) return null;
  letter = letter.toUpperCase();
  for (const opt of options) {
    // option may start with "A. text" or "A text" or just "text"
    const m = opt.match(/^\s*([A-E])\.?\s*(.*)/i);
    if (m) {
      if (m[1].toUpperCase() === letter) return opt;
    }
  }
  return null;
}

(async () => {
  const years = [2023, 2024, 2025];
  const out = { timestamp: new Date().toISOString(), imported: {} };
  for (const year of years) {
    const qPath = path.join(__dirname, '..', 'assets', 'bece_rme_1999_2022', `bece_${year}_questions.json`);
    const aPath = path.join(__dirname, '..', 'assets', 'bece_rme_1999_2022', `bece_${year}_answers.json`);
    if (!fs.existsSync(qPath)) { console.warn('Questions file not found for', year); continue; }
    if (!fs.existsSync(aPath)) { console.warn('Answers file not found for', year); continue; }
    const qRaw = JSON.parse(fs.readFileSync(qPath, 'utf8'));
    const aRaw = JSON.parse(fs.readFileSync(aPath, 'utf8'));
    const qMap = qRaw.multiple_choice || qRaw.multipleChoice || qRaw.questions || {};
    const aMap = aRaw.multiple_choice || aRaw.multipleChoice || {};
    const imported = [];
    for (const key of Object.keys(qMap)) {
      // expect keys like q1, q2 or numeric
      const m = key.match(/q(\d+)/i);
      const qnum = m ? Number(m[1]) : null;
      const qObj = qMap[key];
      // qObj may be { question: '...', possibleAnswers: [...] } or { questionText: '', options: [] }
      let questionText = qObj.question || qObj.questionText || qObj.question_text || '';
      questionText = normalizeQuestionText(questionText);
      const options = qObj.possibleAnswers || qObj.possible_answers || qObj.options || [];
      // get answer from aMap
      const aVal = aMap[key];
      let correctAnswer = null;
      if (typeof aVal === 'string') {
        const trimmed = aVal.trim();
        if (/^[A-E]$/i.test(trimmed)) {
          correctAnswer = findOptionByLetter(options, trimmed);
        } else {
          // sometimes answers include full option text or "B. text"
          // try to match by starting letter
          const letterMatch = trimmed.match(/^([A-E])\b/);
          if (letterMatch) correctAnswer = findOptionByLetter(options, letterMatch[1]);
          else {
            // try to find option that includes the answer text
            const found = options.find(o => o.toLowerCase().includes(trimmed.toLowerCase()));
            correctAnswer = found || trimmed;
          }
        }
      }

      const id = `rme_${year}_q${qnum || Math.floor(Math.random()*100000)}`;
      const doc = {
        id,
        questionText,
        type: 'multipleChoice',
        subject: 'religiousMoralEducation',
        subjectName: 'Religious And Moral Education',
        subjectCode: 'RME',
        examType: 'bece',
        examName: 'Basic Education Certificate Examination',
        year: String(year),
        section: 'A',
        questionNumber: qnum,
        options,
        correctAnswer: correctAnswer || null,
        explanation: `BECE ${year} RME Question ${qnum || ''}`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Religious And Moral Education', 'BECE', String(year)],
        tags: ['rme', 'bece', String(year), 'past-question'],
        createdBy: 'bulk_import_script',
        isActive: true,
        isPremium: false,
        metadata: {
          source: `BECE ${year} RME`,
          importDate: new Date().toISOString(),
          verified: true,
          version: '2.0'
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      try {
        await db.collection('questions').doc(id).set(doc);
        imported.push(id);
      } catch (e) {
        console.error('Failed writing', id, e && e.message ? e.message : e);
      }
    }
    out.imported[year] = imported;
    console.log(`Imported ${imported.length} docs for ${year}`);
  }
  const outPath = path.join(__dirname, 'output', 'import_bece_rme_2023_2025_report.json');
  if (!fs.existsSync(path.dirname(outPath))) fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log('Wrote report to', outPath);
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
