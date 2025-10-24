const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();
const assetsDir = path.join(__dirname, '..', 'assets', 'bece_ict');
const years = [2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022];

async function processYear(year) {
  const qFile = path.join(assetsDir, `bece_ict_${year}_questions.json`);
  const aFile = path.join(assetsDir, `bece_ict_${year}_answers.json`);
  if (!fs.existsSync(qFile)) {
    console.warn(`Skipping ${year}: missing questions file`);
    return { overwritten:0, skipped:0, total:0 };
  }

  const qRaw = JSON.parse(fs.readFileSync(qFile, 'utf8'));
  const aRaw = fs.existsSync(aFile) ? JSON.parse(fs.readFileSync(aFile, 'utf8')) : {};

  let questionsMap = {};
  if (qRaw && qRaw.multiple_choice) {
    questionsMap = qRaw.multiple_choice;
  } else if (Array.isArray(qRaw)) {
    qRaw.forEach((q, idx) => { questionsMap[`q${idx+1}`] = { question: q.question || q.questionText || q.q, possibleAnswers: q.possibleAnswers || q.options || [] }; });
  } else {
    questionsMap = qRaw;
  }

  let overwritten = 0, total = 0;

  for (const key of Object.keys(questionsMap)) {
    total++;
    const num = parseInt(key.replace(/[^0-9]/g,''), 10) || total;
    const q = questionsMap[key];
    const ans = aRaw ? (aRaw[key] || aRaw[key.toLowerCase()] || null) : null;

    const questionText = (q.question || q.questionText || q.q || '').toString();
    const options = q.possibleAnswers || q.options || q.choices || [];
    let correct = null;
    let fullAnswer = null;
    if (ans) {
      if (typeof ans === 'string') {
        fullAnswer = ans;
        const m = ans.match(/^([A-E])\b|^([A-E])\./i);
        if (m) correct = (m[1] || m[2]).toUpperCase();
        if (!correct) {
          correct = ans.trim().charAt(0).toUpperCase();
        }
      } else if (typeof ans === 'object') {
        fullAnswer = JSON.stringify(ans);
        correct = ans.answer || ans.correct || null;
      }
    }

    const docId = `ict_${year}_q${num}`;
    try {
      const ref = db.collection('questions').doc(docId);
      const snap = await ref.get();
      const now = new Date();
      const createdAt = snap.exists && snap.data().createdAt ? snap.data().createdAt : now.toISOString();

      const doc = {
        id: docId,
        questionText: questionText,
        type: 'multipleChoice',
        subject: 'ict',
        examType: 'bece',
        year: year.toString(),
        section: 'A',
        questionNumber: num,
        options: options,
        correctAnswer: correct || (fullAnswer ? fullAnswer.split('.')[0] : ''),
        fullAnswer: fullAnswer || null,
        explanation: `Imported from BECE ${year} ICT`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Information And Communication Technology','ICT','BECE', year.toString()],
        createdAt: createdAt,
        updatedAt: now.toISOString(),
        createdBy: 'bulk_import_script',
        isActive: true,
        metadata: {
          source: `BECE ${year} ICT`,
          importDate: now.toISOString(),
          verified: true,
          timestamp: Date.now()
        }
      };

      await ref.set(doc, { merge: false });
      overwritten++;
      console.log(`Overwrote ${docId}`);
    } catch (e) {
      console.error('Error writing', docId, e.message || e);
    }
  }

  return { overwritten, total };
}

(async () => {
  let totalOverwritten = 0, totalCount = 0;
  for (const y of years) {
    const res = await processYear(y);
    console.log(`Year ${y}: overwritten=${res.overwritten}, total=${res.total}`);
    totalOverwritten += res.overwritten;
    totalCount += res.total;
  }

  console.log('Done. Summary:');
  console.log('Total expected from assets:', totalCount);
  console.log('Overwritten now:', totalOverwritten);

  const snap = await db.collection('questions').where('subject','==','ict').get();
  console.log('Firestore ICT total now:', snap.size);
  await admin.app().delete();
})();
