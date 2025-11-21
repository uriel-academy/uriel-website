const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function checkMathImages() {
  const targets = [
    { year: '2025', question: 15 },
    { year: '1992', question: 3 },
    { year: '1992', question: 13 },
    { year: '1992', question: 14 },
    { year: '1992', question: 19 },
  ];

  for (const { year, question } of targets) {
    const snap = await db.collection('questions')
      .where('year', '==', year)
      .where('subject', '==', 'mathematics')
      .where('questionNumber', '==', question)
      .get();
    if (snap.empty) {
      console.log(`Year: ${year}, Q${question}: NOT FOUND`);
      continue;
    }
    snap.forEach(doc => {
      const data = doc.data();
      console.log(`Year: ${year}, Q${question}:`);
      console.log('  imageBeforeQuestion:', data.imageBeforeQuestion || null);
      console.log('  imageAfterQuestion:', data.imageAfterQuestion || null);
      console.log('  optionImages:', data.optionImages || null);
    });
  }
  process.exit(0);
}

checkMathImages().catch(e => { console.error(e); process.exit(1); });
