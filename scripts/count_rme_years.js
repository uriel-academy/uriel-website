#!/usr/bin/env node
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize admin using service account from repo if available
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
  console.log('Initialized admin SDK using', found);
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  initialized = true;
  console.log('Initialized admin SDK using Application Default Credentials');
}
if (!initialized) { console.error('No service account available.'); process.exit(1); }

const db = admin.firestore();

(async () => {
  const years = [2023, 2024, 2025];
  // Check multiple subject variants and both string/number year types
  const subjectVariants = [
    'religiousMoralEducation',
    'Religious and Moral Education - RME',
    'Religious And Moral Education',
    'RME'
  ];
  const report = { timestamp: new Date().toISOString(), counts: {} };
  for (const y of years) {
    report.counts[y] = {};
    for (const subj of subjectVariants) {
      // check year as string and as number
      const snapStr = await db.collection('questions')
        .where('examType', '==', 'bece')
        .where('subject', '==', subj)
        .where('year', '==', String(y)).get();
      const snapNum = await db.collection('questions')
        .where('examType', '==', 'bece')
        .where('subject', '==', subj)
        .where('year', '==', y).get();
      report.counts[y][subj] = { asString: snapStr.size, asNumber: snapNum.size };
    }
  }
  const outDir = path.join(__dirname, 'output');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'rme_import_summary.json');
  fs.writeFileSync(outPath, JSON.stringify(report, null, 2));
  console.log('Wrote report to', outPath);
  console.log(JSON.stringify(report, null, 2));
  process.exit(0);
})().catch(err => { console.error(err && err.stack ? err.stack : err); process.exit(1); });
