const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkCurrentData() {
  const years = ['2017', '2020', '2025'];
  
  for (const y of years) {
    const snap = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .where('year', '==', y)
      .where('questionNumber', '==', 1)
      .limit(1)
      .get();
    
    if (!snap.empty) {
      const d = snap.docs[0].data();
      const text = d.questionText;
      
      console.log(`\n=== ${y} ===`);
      
      // Check for different instruction patterns
      if (text.includes('three parts: A, B and C')) {
        console.log('Format: 3 PARTS (A, B, C)');
      } else if (text.includes('two parts')) {
        console.log('Format: 2 PARTS');
      } else {
        console.log('Format: COMPOSITION ONLY');
      }
      
      console.log('Preview:', text.substring(0, 200));
    }
  }
  
  process.exit(0);
}

checkCurrentData();
