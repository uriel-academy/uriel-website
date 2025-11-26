const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function check1990() {
  // First check what years exist
  const allSnap = await db.collection('questions')
    .where('type', '==', 'essay')
    .where('subject', '==', 'english')
    .limit(5)
    .get();
  
  console.log('Sample documents:');
  allSnap.docs.forEach(doc => {
    const data = doc.data();
    console.log(`  Year: ${data.year} (type: ${typeof data.year}), Q${data.questionNumber}, Subject: ${data.subject}`);
  });
  
  // Try with string
  const snapshot = await db.collection('questions')
    .where('type', '==', 'essay')
    .where('subject', '==', 'english')
    .where('year', '==', '1990')
    .orderBy('questionNumber')
    .get();

  console.log(`\nFound ${snapshot.docs.length} documents for year 1990`);
  
  if (snapshot.docs.length === 0) {
    console.log('No documents found!');
    return;
  }
  
  console.log('\n1990 English Q1 questionText:');
  console.log('='.repeat(80));
  console.log(snapshot.docs[0].data().questionText);
  console.log('='.repeat(80));
  console.log('\nChecking for patterns:');
  const text = snapshot.docs[0].data().questionText;
  console.log('Has "three parts":', text.includes('three parts'));
  console.log('Has "PART A":', text.includes('PART A'));
  console.log('Has "Answer ONE":', text.includes('Answer ONE'));
  console.log('Has "composition":', text.toLowerCase().includes('composition'));
  
  process.exit(0);
}

check1990();
