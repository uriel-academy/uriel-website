const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function sanitizeAllMathImageUrls() {
  console.log('Starting sanitization of all mathematics image URLs...');

  const snap = await db.collection('questions')
    .where('subject', '==', 'mathematics')
    .get();

  let updatedCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    let needsUpdate = false;
    const updates = {};

    // Check imageBeforeQuestion
    if (data.imageBeforeQuestion && typeof data.imageBeforeQuestion === 'string') {
      let url = data.imageBeforeQuestion.replace(/\s+/g, '');
      if (!url.startsWith('http')) {
        url = 'https://' + url.replace(/^https?:\/\//, '');
      }
      if (url !== data.imageBeforeQuestion) {
        updates.imageBeforeQuestion = url;
        needsUpdate = true;
      }
    }

    // Check imageAfterQuestion
    if (data.imageAfterQuestion && typeof data.imageAfterQuestion === 'string') {
      let url = data.imageAfterQuestion.replace(/\s+/g, '');
      if (!url.startsWith('http')) {
        url = 'https://' + url.replace(/^https?:\/\//, '');
      }
      if (url !== data.imageAfterQuestion) {
        updates.imageAfterQuestion = url;
        needsUpdate = true;
      }
    }

    if (needsUpdate) {
      await doc.ref.update(updates);
      updatedCount++;
      console.log(`Updated ${data.year} Q${data.questionNumber}: ${Object.keys(updates).join(', ')}`);
    }
  }

  console.log(`Sanitization complete. Updated ${updatedCount} questions.`);
  process.exit(0);
}

sanitizeAllMathImageUrls().catch(e => { console.error(e); process.exit(1); });
