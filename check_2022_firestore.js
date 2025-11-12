const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function check2022() {
  console.log('Fetching all 2022 Integrated Science questions from Firestore...\n');
  
  const snapshot = await db.collection('questions')
    .where('year', '==', '2022')
    .where('subject', '==', 'Integrated Science')
    .get();
  
  console.log(`Found ${snapshot.size} questions\n`);
  
  const numbers = [];
  snapshot.forEach(doc => {
    numbers.push(doc.data().questionNumber);
  });
  
  console.log('Question numbers:', numbers);
  
  // Find missing
  const existing = new Set(numbers);
  const missing = [];
  for (let i = 1; i <= 40; i++) {
    if (!existing.has(i)) missing.push(i);
  }
  
  console.log('\nMissing:', missing);
  
  // Show Q9 if it exists
  const q9 = snapshot.docs.find(doc => doc.data().questionNumber === 9);
  if (q9) {
    const data = q9.data();
    console.log('\n\n=== Question 9 ===');
    console.log(`Question: ${data.questionText}`);
    console.log(`Options:`, data.options);
  }
  
  process.exit(0);
}

check2022().catch(console.error);
