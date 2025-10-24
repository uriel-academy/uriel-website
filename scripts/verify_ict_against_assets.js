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

async function compareYear(year) {
  const qFile = path.join(assetsDir, `bece_ict_${year}_questions.json`);
  if (!fs.existsSync(qFile)) {
    console.warn(`Assets missing for ${year}`);
    return { checked:0, missingDocs:0, mismatches:0, missingAssets: true };
  }

  const qRaw = JSON.parse(fs.readFileSync(qFile, 'utf8'));
  let questionsMap = {};
  if (qRaw && qRaw.multiple_choice) {
    questionsMap = qRaw.multiple_choice;
  } else if (Array.isArray(qRaw)) {
    qRaw.forEach((q, idx) => { questionsMap[`q${idx+1}`] = { question: q.question || q.questionText || q.q, possibleAnswers: q.possibleAnswers || q.options || [] }; });
  } else {
    questionsMap = qRaw;
  }

  let checked = 0, missingDocs = 0, mismatches = 0;

  for (const key of Object.keys(questionsMap)) {
    const num = parseInt(key.replace(/[^0-9]/g,''), 10) || 0;
    const docId = `ict_${year}_q${num}`;
    checked++;
    const doc = await db.collection('questions').doc(docId).get();
    if (!doc.exists) {
      missingDocs++;
      console.log(`[MISSING DOC] ${docId} not found in Firestore`);
      continue;
    }
    const data = doc.data();
    const assetQuestion = (questionsMap[key].question || questionsMap[key].questionText || '').toString().trim();
    const firestoreQuestion = (data.questionText || '').toString().trim();
    if (assetQuestion !== firestoreQuestion) {
      mismatches++;
      console.log(`[MISMATCH] ${docId} question text differs`);
      console.log(`  asset: ${assetQuestion.substring(0,120)}`);
      console.log(`  db:    ${firestoreQuestion.substring(0,120)}`);
    }

    // Compare options count
    const assetOptions = questionsMap[key].possibleAnswers || questionsMap[key].options || [];
    const dbOptions = data.options || [];
    if (assetOptions.length !== dbOptions.length) {
      mismatches++;
      console.log(`[MISMATCH] ${docId} options length differ asset=${assetOptions.length} db=${dbOptions.length}`);
    }
  }

  return { checked, missingDocs, mismatches, missingAssets: false };
}

(async () => {
  let totalChecked = 0, totalMissing = 0, totalMismatches = 0, missingAssetYears = [];
  for (const y of years) {
    const res = await compareYear(y);
    if (res.missingAssets) missingAssetYears.push(y);
    totalChecked += res.checked;
    totalMissing += res.missingDocs;
    totalMismatches += res.mismatches;
    console.log(`Year ${y}: checked=${res.checked}, missingDocs=${res.missingDocs}, mismatches=${res.mismatches}`);
  }

  console.log('--- SUMMARY ---');
  console.log('Total checked from assets:', totalChecked);
  console.log('Total missing docs in Firestore:', totalMissing);
  console.log('Total mismatches found:', totalMismatches);
  if (missingAssetYears.length) console.log('Missing asset files for years:', missingAssetYears.join(', '));

  await admin.app().delete();
})();
