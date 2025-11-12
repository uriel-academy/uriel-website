const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAll() {
  console.log('Checking all Integrated Science questions in Firestore...\n');
  
  const snapshot = await db.collection('questions')
    .where('subject', '==', 'Integrated Science')
    .get();
  
  console.log(`Total Integrated Science questions: ${snapshot.size}\n`);
  
  // Group by year
  const byYear = {};
  snapshot.forEach(doc => {
    const year = doc.data().year;
    if (!byYear[year]) byYear[year] = 0;
    byYear[year]++;
  });
  
  console.log('By year:');
  for (let year = 1990; year <= 2025; year++) {
    const count = byYear[year.toString()] || 0;
    if (count > 0) {
      console.log(`  ${year}: ${count} questions`);
    }
  }
  
  process.exit(0);
}

checkAll().catch(console.error);
