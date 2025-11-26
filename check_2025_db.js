const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function check2025() {
  const snapshot = await db.collection('questions')
    .where('type', '==', 'essay')
    .where('subject', '==', 'english')
    .where('year', '==', '2025')
    .orderBy('questionNumber')
    .get();

  console.log(`Found ${snapshot.docs.length} documents for 2025\n`);
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    console.log(`Q${data.questionNumber}:`);
    console.log(`  partHeader: ${data.partHeader}`);
    console.log(`  paperInstructions: ${data.paperInstructions ? 'YES - ' + data.paperInstructions.substring(0, 80) + '...' : 'NONE'}`);
    console.log(`  questionText start: ${data.questionText.substring(0, 100)}...`);
    console.log();
  });
  
  process.exit(0);
}

check2025();
