const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQ5() {
  const years = ['2023', '2024', '2025'];
  
  for (const year of years) {
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .where('year', '==', year)
      .where('questionNumber', '==', 5)
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      const d = snapshot.docs[0].data();
      const text = d.questionText;
      console.log(`\n=== ${year} Q5 ===`);
      console.log('Length:', text.length);
      console.log('Has (h):', text.includes('(h)'));
      console.log('Has (i):', text.includes('(i)'));
      console.log('Has (j):', text.includes('(j)'));
      
      // Show last 500 chars
      console.log('\nLast 500 chars:');
      console.log(text.substring(text.length - 500));
    }
  }
  
  process.exit(0);
}

checkQ5();
