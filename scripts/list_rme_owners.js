const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!admin.apps.length) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

async function run() {
  const outDir = path.join(__dirname, 'output');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const rows = [];

  const snapshot = await db.collection('questions')
    .where('subject', '==', 'religiousMoralEducation')
    .where('isActive', '==', true)
    .get();

  console.log('Found RME docs:', snapshot.docs.length);

  for (const doc of snapshot.docs) {
    const d = doc.data();
    const id = d.id || doc.id;
    const year = d.year || '';
    const qnum = d.questionNumber || '';
    const createdBy = d.createdBy || (d.metadata && d.metadata.createdBy) || '';
    const importBy = d.metadata && d.metadata.importedBy ? d.metadata.importedBy : '';
    const answerKeyUpdated = d.metadata && d.metadata.answerKeyUpdated ? d.metadata.answerKeyUpdated : false;
    const answerKeyBy = d.metadata && d.metadata.answerKeyUpdatedBy ? d.metadata.answerKeyUpdatedBy : '';
    const source = d.metadata && d.metadata.source ? d.metadata.source : '';
    rows.push({ id, year, qnum, createdBy, importBy, answerKeyUpdated, answerKeyBy, source });
  }

  // write CSV
  const csvPath = path.join(outDir, 'rme_owners.csv');
  const header = 'id,year,questionNumber,createdBy,importBy,answerKeyUpdated,answerKeyUpdatedBy,source\n';
  const lines = rows.map(r => `${r.id},${r.year},${r.qnum},"${r.createdBy}","${r.importBy}",${r.answerKeyUpdated},"${r.answerKeyBy}","${r.source}"`).join('\n');
  fs.writeFileSync(csvPath, header + lines);
  console.log('Wrote CSV to', csvPath);

  // summarize unique users
  const creators = {};
  const answerUpdaters = {};
  for (const r of rows) {
    if (r.createdBy) creators[r.createdBy] = (creators[r.createdBy] || 0) + 1;
    if (r.answerKeyBy) answerUpdaters[r.answerKeyBy] = (answerUpdaters[r.answerKeyBy] || 0) + 1;
  }

  console.log('\nUnique creators:');
  for (const k of Object.keys(creators)) console.log(`  ${k}: ${creators[k]}`);
  console.log('\nUnique answerKeyUpdaters:');
  for (const k of Object.keys(answerUpdaters)) console.log(`  ${k}: ${answerUpdaters[k]}`);

  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(2); });
