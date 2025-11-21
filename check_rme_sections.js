const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRMESections() {
  try {
    console.log('🔍 Checking RME sections for 2024 and 2025...');

    const years = ['2024', '2025'];

    for (const year of years) {
      const query = db.collection('questions')
        .where('subject', '==', 'religiousMoralEducation')
        .where('year', '==', year);

      const snapshot = await query.get();

      const sections = {};
      snapshot.docs.forEach(doc => {
        const data = doc.data();
        const section = data.section;
        if (!sections[section]) sections[section] = 0;
        sections[section]++;
      });

      console.log(`📅 ${year}:`);
      for (const section in sections) {
        console.log(`   Section ${section}: ${sections[section]} questions`);
      }
      console.log(`   Total: ${snapshot.docs.length} questions`);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkRMESections();