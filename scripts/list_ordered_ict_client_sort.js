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

(async () => {
  try {
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ict')
      .where('examType', '==', 'bece')
      .where('isActive', '==', true)
      .get();

    console.log('Total matched (unsorted):', snapshot.size);
    const docs = snapshot.docs.map(doc => doc.data());

    docs.sort((a, b) => {
      const ay = parseInt(a.year) || 0;
      const by = parseInt(b.year) || 0;
      if (ay !== by) return ay - by;
      const aq = a.questionNumber || 0;
      const bq = b.questionNumber || 0;
      return aq - bq;
    });

    const out = docs.slice(0, 20).map(d => ({ id: d.id, year: d.year, qnum: d.questionNumber, text: (d.questionText||'').replace(/\n/g,' ') }));
    console.log(JSON.stringify(out, null, 2));
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
