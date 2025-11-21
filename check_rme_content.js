const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRMEContent() {
  try {
    console.log('🔍 Checking RME 2024 and 2025 question content...');

    const years = ['2024', '2025'];

    for (const year of years) {
      console.log(`\n📅 ${year} RME questions:`);

      const query = db.collection('questions')
        .where('subject', '==', 'religiousMoralEducation')
        .where('year', '==', year)
        .limit(10); // Check first 10

      const snapshot = await query.get();

      snapshot.docs.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\nQ${index + 1}: ${data.questionText?.substring(0, 100)}...`);
        console.log(`   Options: ${data.options?.length}`);
        console.log(`   Correct: ${data.correctAnswer}`);
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkRMEContent();