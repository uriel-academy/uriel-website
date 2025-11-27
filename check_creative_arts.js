const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkCreativeArts() {
  try {
    const collections = await db.collection('subjects').doc('creativeArts').collection('topicCollections').get();
    console.log('Creative Arts collections in Firestore:');
    let totalQuestions = 0;
    collections.forEach(doc => {
      const data = doc.data();
      console.log(`- ${data.name}: ${data.questionCount} questions`);
      totalQuestions += data.questionCount;
    });
    console.log(`Total: ${collections.size} collections, ${totalQuestions} questions`);
  } catch (error) {
    console.error('Error checking Creative Arts collections:', error);
  }
}

checkCreativeArts().then(() => process.exit(0));