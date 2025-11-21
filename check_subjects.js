const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAllSubjects() {
  try {
    console.log('🔍 Checking all subjects in questions collection...');

    const query = db.collection('questions').limit(1000); // Sample
    const snapshot = await query.get();

    const subjects = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const subject = data.subject;
      if (!subjects[subject]) subjects[subject] = 0;
      subjects[subject]++;
    });

    console.log('📋 Subjects found:');
    for (const subject in subjects) {
      console.log(`   ${subject}: ${subjects[subject]} questions`);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkAllSubjects();