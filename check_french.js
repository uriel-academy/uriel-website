const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFrenchCollections() {
  try {
    const collections = await db.collection('questionCollections')
      .where('subject', '==', 'french')
      .get();

    console.log('French collections in questionCollections:');
    let totalQuestions = 0;
    collections.forEach(doc => {
      const data = doc.data();
      console.log(`- ${data.name}: ${data.questionCount} questions`);
      totalQuestions += data.questionCount;
    });
    console.log(`Total: ${collections.size} collections, ${totalQuestions} questions`);
  } catch (error) {
    console.error('Error checking French collections:', error);
  }
}

checkFrenchCollections().then(() => process.exit(0));