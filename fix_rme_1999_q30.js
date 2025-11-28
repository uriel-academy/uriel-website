// Fix RME 1999 Q30 answer mismatch
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixRmeAnswer() {
  const docRef = db.collection('questions').doc('rme_1999_q30');
  
  const doc = await docRef.get();
  if (!doc.exists) {
    console.log('❌ Document not found');
    return;
  }

  const data = doc.data();
  console.log('Current answer:', data.correctAnswer);
  console.log('Question:', data.questionText);
  console.log('\nOptions:');
  data.options.forEach((opt, i) => console.log(`  ${i}: ${opt}`));

  // Official answer is A: "sweep the compound"
  const correctAnswer = 'A. sweep the compound';

  await docRef.update({
    correctAnswer: correctAnswer
  });

  console.log('\n✅ Updated answer from "C. pay the school fees" to "A. sweep the compound"');
  console.log('This matches the official BECE 1999 RME answer key.');
  
  process.exit();
}

fixRmeAnswer().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
