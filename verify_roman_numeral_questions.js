const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQuestion() {
  console.log('Checking 2022 Integrated Science Question 9 in Firestore...\n');
  
  const snapshot = await db.collection('questions')
    .where('year', '==', '2022')
    .where('subject', '==', 'Integrated Science')
    .where('questionNumber', '==', 9)
    .get();
  
  if (snapshot.empty) {
    console.log('❌ Question 9 NOT FOUND in Firestore');
  } else {
    snapshot.forEach(doc => {
      const q = doc.data();
      console.log('✅ Question 9 FOUND in Firestore!');
      console.log(`ID: ${doc.id}`);
      console.log(`Question: ${q.questionText}`);
      console.log(`Options:`, q.options);
      console.log(`Correct Answer: ${q.correctAnswer}`);
      console.log(`Full Answer: ${q.fullAnswerText}`);
    });
  }
  
  console.log('\n\nChecking Question 14...\n');
  
  const snapshot14 = await db.collection('questions')
    .where('year', '==', '2022')
    .where('subject', '==', 'Integrated Science')
    .where('questionNumber', '==', 14)
    .get();
  
  if (snapshot14.empty) {
    console.log('❌ Question 14 NOT FOUND in Firestore');
  } else {
    snapshot14.forEach(doc => {
      const q = doc.data();
      console.log('✅ Question 14 FOUND in Firestore!');
      console.log(`ID: ${doc.id}`);
      console.log(`Question: ${q.questionText}`);
      console.log(`Options:`, q.options);
      console.log(`Correct Answer: ${q.correctAnswer}`);
      console.log(`Full Answer: ${q.fullAnswerText}`);
    });
  }
  
  process.exit(0);
}

checkQuestion().catch(console.error);
