const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAll() {
  console.log('Checking questions collection...\n');
  
  const snapshot = await db.collection('questions').limit(10).get();
  
  console.log(`Sample of ${snapshot.size} questions:\n`);
  
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`ID: ${doc.id}`);
    console.log(`Subject: ${data.subject}, Year: ${data.year}, Q#: ${data.questionNumber}`);
    console.log(`Question: ${data.questionText?.substring(0, 60)}...`);
    console.log('---');
  });
  
  // Count all questions
  const allSnapshot = await db.collection('questions').count().get();
  console.log(`\n\nTotal questions in Firestore: ${allSnapshot.data().count}`);
  
  process.exit(0);
}

checkAll().catch(console.error);
