const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  for (const subject of ['french', 'creativeArts']) {
    try {
      const snapshot = await db.collection('questions').where('subject', '==', subject).where('examType', '==', 'bece').limit(5).get();
      console.log(`Subject=${subject} -> count (sample limit 5): ${snapshot.size}`);
      snapshot.docs.forEach(doc => {
        console.log('  ', doc.id, '->', {
          questionNumber: doc.data().questionNumber,
          questionText: (doc.data().questionText || '').slice(0, 80),
          options: doc.data().options ? doc.data().options.length : 0,
          correctAnswer: doc.data().correctAnswer,
          imageAfterQuestion: doc.data().imageAfterQuestion || null,
        });
      });
    } catch (e) {
      console.error('Query failed for', subject, e && e.message ? e.message : e);
    }
  }
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
