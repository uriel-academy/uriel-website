const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function sanitizeMathImageUrls() {
  const targets = [
    { year: '1992', question: 3 },
    { year: '1992', question: 13 },
    { year: '1992', question: 14 },
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
    for (const doc of snap.docs) {
      const data = doc.data();
      let url = data.imageBeforeQuestion;
      if (typeof url === 'string') {
        // Remove whitespace, newlines, and ensure https://
        url = url.replace(/\s+/g, '');
        if (!url.startsWith('http')) {
          url = 'https://' + url.replace(/^https?:\/\//, '');
        }
        await doc.ref.update({ imageBeforeQuestion: url });
        console.log(`Sanitized Year: ${year}, Q${question}: ${url}`);
      }
    }
  }
  process.exit(0);
}

sanitizeMathImageUrls().catch(e => { console.error(e); process.exit(1); });
