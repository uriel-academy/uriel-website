const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkCollectionIds() {
  const collections = await db.collection('questionCollections').get();
  collections.forEach(doc => {
    const data = doc.data();
    if (data.subject === 'asanteTwi' && data.name.includes('Food & Drinks')) {
      console.log(`Asante Twi Food & Drinks collection ID: ${doc.id}`);
    }
  });
}

checkCollectionIds().then(() => process.exit(0));