const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRMEDuplicates() {
  try {
    console.log('🔍 Checking for RME duplicates...');

    const query = db.collection('questions').where('subject', '==', 'religiousMoralEducation');
    const snapshot = await query.get();

    const byYearQuestion = {};

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const key = `${data.year}_${data.questionNumber}`;
      if (!byYearQuestion[key]) byYearQuestion[key] = [];
      byYearQuestion[key].push(doc.id);
    });

    let totalDuplicates = 0;
    for (const key in byYearQuestion) {
      const ids = byYearQuestion[key];
      if (ids.length > 1) {
        console.log(`⚠️  Duplicate: ${key} has ${ids.length} copies`);
        totalDuplicates += ids.length - 1;
      }
    }

    console.log(`📊 Total duplicate questions: ${totalDuplicates}`);

    // Check 2024 and 2025 specifically
    ['2024', '2025'].forEach(year => {
      const yearKeys = Object.keys(byYearQuestion).filter(k => k.startsWith(year + '_'));
      let yearCount = 0;
      yearKeys.forEach(k => {
        const ids = byYearQuestion[k];
        yearCount += ids.length;
      });
      console.log(`📅 ${year}: ${yearCount} total documents`);
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkRMEDuplicates();