const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function fixQ3() {
  // Get Q3 from 2025
  const snapshot = await db.collection('questions')
    .where('subject', '==', 'mathematics')
    .where('year', '==', '2025')
    .where('questionNumber', '==', 3)
    .get();
  
  if (snapshot.empty) {
    console.log('Q3 not found');
    return;
  }
  
  const doc = snapshot.docs[0];
  console.log('Found Q3, current state:', doc.data());
  
  // Update with correct data
  await doc.ref.update({
    questionText: 'When 0.24 is expressed in the lowest form as a/b, the denominator is',
    options: [
      'A. 2.',
      'B. 5.',
      'C. 25.',
      'D. 125.'
    ],
    correctAnswer: 'C',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log('✅ Updated Q3 with 4 options');
  
  // Verify
  const updated = await doc.ref.get();
  const data = updated.data();
  console.log('Verified - Options:', data.options);
  
  process.exit(0);
}

fixQ3().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
