const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRMEByExamType() {
  try {
    console.log('🔍 Checking RME questions by exam type...');

    const query = db.collection('questions').where('subject', '==', 'religiousMoralEducation');
    const snapshot = await query.get();

    const byExamType = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const examType = data.examType;
      if (!byExamType[examType]) byExamType[examType] = {};
      if (!byExamType[examType][data.year]) byExamType[examType][data.year] = 0;
      byExamType[examType][data.year]++;
    });

    for (const examType in byExamType) {
      console.log(`📋 Exam Type: ${examType}`);
      for (const year in byExamType[examType]) {
        console.log(`   ${year}: ${byExamType[examType][year]} questions`);
      }
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkRMEByExamType();