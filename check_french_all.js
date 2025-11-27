const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFrenchCollections() {
  try {
    // Get all collections and filter for French ones
    const allCollections = await db.collection('questionCollections').get();
    console.log('All collections in questionCollections:');
    let frenchCollections = [];
    allCollections.forEach(doc => {
      const data = doc.data();
      if (data.name && data.name.includes('French')) {
        frenchCollections.push(data);
        console.log(`- ${data.name}: subject=${data.subject}, questions=${data.questionCount}`);
      }
    });
    console.log(`Total French collections found: ${frenchCollections.length}`);
  } catch (error) {
    console.error('Error checking French collections:', error);
  }
}

checkFrenchCollections().then(() => process.exit(0));