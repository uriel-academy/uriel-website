const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://uriel-academy-41fb0-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function clearTriviaQuestions() {
  console.log('🗑️ Clearing existing trivia questions...');

  try {
    // Delete all questions where subject='trivia' and examType='trivia'
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'trivia')
      .where('examType', '==', 'trivia')
      .get();

    console.log(`Found ${snapshot.docs.length} trivia questions to delete`);

    // Delete in batches
    const batchSize = 500;
    let deleted = 0;

    for (let i = 0; i < snapshot.docs.length; i += batchSize) {
      const batch = db.batch();
      const batchDocs = snapshot.docs.slice(i, i + batchSize);

      for (const doc of batchDocs) {
        batch.delete(doc.ref);
      }

      await batch.commit();
      deleted += batchDocs.length;
      console.log(`   ✅ Deleted batch ${Math.floor(i / batchSize) + 1} (${batchDocs.length} questions)`);
    }

    console.log(`✨ Successfully deleted ${deleted} trivia questions`);

  } catch (error) {
    console.error('❌ Error clearing trivia questions:', error);
  } finally {
    admin.app().delete();
  }
}

clearTriviaQuestions();