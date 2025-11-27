const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAllCollections() {
  try {
    const collections = await db.collection('questionCollections').limit(10).get();
    console.log('First 10 collections in questionCollections:');
    collections.forEach(doc => {
      const data = doc.data();
      console.log(`- ${data.name}: subject=${data.subject}, questions=${data.questionCount}`);
    });
    console.log(`Total collections found: ${collections.size}`);
  } catch (error) {
    console.error('Error checking collections:', error);
  }
}

checkAllCollections().then(() => process.exit(0));
