const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAllRME() {
  try {
    console.log('🔍 Checking all RME questions...');

    const query = db.collection('questions').where('subject', '==', 'religiousMoralEducation');
    const snapshot = await query.get();

    console.log(`📊 Total RME questions: ${snapshot.docs.length}`);

    // Group by year
    const byYear = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const year = data.year;
      if (!byYear[year]) byYear[year] = [];
      byYear[year].push(data.questionNumber);
    });

    for (const year in byYear) {
      const questions = byYear[year].sort((a,b) => a-b);
      console.log(`📅 ${year}: ${questions.length} questions`);
      console.log(`   Numbers: ${questions.slice(0,10).join(', ')}${questions.length > 10 ? '...' : ''}`);

      // Check for duplicates
      const unique = [...new Set(questions)];
      if (unique.length !== questions.length) {
        console.log(`   ⚠️  Duplicates found!`);
      }
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkAllRME();