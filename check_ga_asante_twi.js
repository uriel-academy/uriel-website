const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkGASubjects() {
  try {
    // Check all collections and filter for GA and Asante Twi
    const allCollections = await db.collection('questionCollections').get();
    console.log('GA and Asante Twi collections in questionCollections:');
    let gaCollections = [];
    let asanteTwiCollections = [];
    allCollections.forEach(doc => {
      const data = doc.data();
      if (data.subject === 'ga') {
        gaCollections.push(data);
        console.log(`GA - ${data.name}: ${data.questionCount} questions`);
      } else if (data.subject === 'asanteTwi') {
        asanteTwiCollections.push(data);
        console.log(`Asante Twi - ${data.name}: ${data.questionCount} questions`);
      }
    });
    console.log(`\nGA: ${gaCollections.length} collections, ${gaCollections.reduce((sum, c) => sum + c.questionCount, 0)} questions`);
    console.log(`Asante Twi: ${asanteTwiCollections.length} collections, ${asanteTwiCollections.reduce((sum, c) => sum + c.questionCount, 0)} questions`);
  } catch (error) {
    console.error('Error checking collections:', error);
  }
}

checkGASubjects().then(() => process.exit(0));