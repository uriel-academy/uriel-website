const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkYears() {
  const years = ['2023', '2024', '2025'];
  
  for (const year of years) {
    console.log(`\n=== ${year} Questions ===`);
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .where('year', '==', year)
      .orderBy('questionNumber')
      .get();
    
    snapshot.forEach(doc => {
      const d = doc.data();
      console.log(`Q${d.questionNumber}: partHeader='${d.partHeader || 'MISSING'}' paperInstructions=${d.paperInstructions ? 'YES' : 'NO'}`);
    });
  }
  
  // Now check the actual text content
  console.log('\n\n=== Checking Q1 text for each year ===');
  for (const year of years) {
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .where('year', '==', year)
      .where('questionNumber', '==', 1)
      .limit(1)
      .get();
    
    if (!snapshot.empty) {
      const d = snapshot.docs[0].data();
      console.log(`\n--- ${year} Q1 (first 300 chars) ---`);
      console.log(d.questionText.substring(0, 300));
    }
  }
  
  process.exit(0);
}

checkYears();
