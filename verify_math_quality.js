const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Get a random mathematics question to verify quality
db.collection('questions')
  .where('subject', '==', 'mathematics')
  .where('year', '==', '2024')
  .limit(3)
  .get()
  .then(snap => {
    console.log('\n🔍 Sample Mathematics Questions from 2024:');
    console.log('=' .repeat(60));
    
    snap.forEach((doc, index) => {
      const q = doc.data();
      console.log(`\nQuestion ${index + 1} (Q${q.questionNumber}):`);
      console.log(`${q.questionText.substring(0, 100)}...`);
      console.log(`\nOptions:`);
      q.options.slice(0, 2).forEach(opt => console.log(`  ${opt}`));
      console.log(`  ...`);
      console.log(`Correct Answer: ${q.correctAnswer}`);
      console.log('-'.repeat(60));
    });
    
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
