const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRMECounts() {
  try {
    console.log('🔍 Checking RME question counts by year...');

    const subject = 'religiousMoralEducation';
    const years = ['2024', '2025'];

    for (const year of years) {
      const query = db.collection('questions')
        .where('subject', '==', subject)
        .where('year', '==', year);

      const snapshot = await query.get();
      console.log(`📊 ${year}: ${snapshot.docs.length} questions`);

      // Show first few question numbers to see if duplicated
      const questionNumbers = snapshot.docs.map(doc => doc.data().questionNumber).sort((a,b) => a-b);
      console.log(`   Question numbers: ${questionNumbers.slice(0,10).join(', ')}${questionNumbers.length > 10 ? '...' : ''}`);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkRMECounts();