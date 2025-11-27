const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function debugCollections() {
  console.log('Checking questionCollections...');
  const allCollections = await db.collection('questionCollections').limit(5).get();
  allCollections.forEach(doc => {
    const data = doc.data();
    console.log(`- ${data.name}: subject=${data.subject}, questions=${data.questionCount}`);
  });

  console.log('\nChecking subjects structure...');
  const subjects = ['rme', 'science', 'social_studies', 'english'];
  for (const subject of subjects) {
    try {
      const collections = await db.collection('subjects').doc(subject).collection('topicCollections').get();
      console.log(`${subject}: ${collections.size} collections`);
    } catch (e) {
      console.log(`${subject}: error - ${e.message}`);
    }
  }
}

debugCollections().then(() => process.exit(0));