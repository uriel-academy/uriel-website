const admin = require('firebase-admin');
const sa = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(sa)
});

const db = admin.firestore();

async function countPassages() {
  const snapshot = await db.collection('french_passages').get();
  console.log('French passages count:', snapshot.size);

  if (snapshot.size > 0) {
    console.log('Sample passage IDs:');
    snapshot.docs.slice(0, 3).forEach(doc => {
      console.log('-', doc.id, ':', doc.data().title);
    });
  }
}

countPassages().catch(console.error);