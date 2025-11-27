const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkSubjectMappings() {
  const collections = await db.collection('questionCollections').get();
  const subjects = new Set();

  collections.forEach(doc => {
    const data = doc.data();
    if (data.subject) {
      subjects.add(data.subject);
    }
  });

  console.log('Unique subjects in questionCollections:');
  subjects.forEach(subject => console.log(`- ${subject}`));

  // Check Mathematics in subjects structure
  const mathCollections = await db.collection('subjects').doc('mathematics').collection('topicCollections').get();
  console.log(`\nMathematics collections in subjects structure: ${mathCollections.size}`);
}

checkSubjectMappings().then(() => process.exit(0));