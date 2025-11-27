const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFrenchCollections() {
  try {
    // Check all collections with french in the name
    const collections = await db.collection('questionCollections')
      .where('name', '>=', 'BECE French')
      .where('name', '<', 'BECE French' + '\uf8ff')
      .get();

    console.log('Collections with "BECE French" in name:');
    let totalQuestions = 0;
    collections.forEach(doc => {
      const data = doc.data();
      console.log(`- ${data.name}: subject=${data.subject}, questions=${data.questionCount}`);
      totalQuestions += data.questionCount;
    });
    console.log(`Total: ${collections.size} collections, ${totalQuestions} questions`);
  } catch (error) {
    console.error('Error checking French collections:', error);
  }
}

checkFrenchCollections().then(() => process.exit(0));