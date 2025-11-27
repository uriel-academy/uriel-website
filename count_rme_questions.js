const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function countRMEQuestions() {
  try {
    console.log('🔍 Counting RME questions in Firestore...\n');

    // Check various possible subject codes for RME
    const subjectCodes = [
      'religiousMoralEducation',
      'RME',
      'religious and moral education',
      'religious_moral_education',
      'rme'
    ];

    let totalRME = 0;
    const subjectCounts = {};

    for (const subjectCode of subjectCodes) {
      const snapshot = await db.collection('questions')
        .where('subject', '==', subjectCode)
        .get();

      if (snapshot.size > 0) {
        console.log(`✅ Found ${snapshot.size} questions with subject '${subjectCode}'`);
        totalRME += snapshot.size;
        subjectCounts[subjectCode] = snapshot.size;
      }
    }

    console.log(`\n📊 Total RME questions found: ${totalRME}`);

    // Also check for any subjects containing 'rme' or 'religious'
    const allSubjectsSnapshot = await db.collection('questions').limit(5000).get();
    const possibleRME = {};

    allSubjectsSnapshot.forEach(doc => {
      const subject = doc.data().subject;
      if (subject && (
        subject.toLowerCase().includes('rme') ||
        subject.toLowerCase().includes('religious') ||
        subject.toLowerCase().includes('moral')
      )) {
        possibleRME[subject] = (possibleRME[subject] || 0) + 1;
      }
    });

    if (Object.keys(possibleRME).length > 0) {
      console.log('\n🔍 Possible RME-related subjects:');
      Object.entries(possibleRME)
        .sort((a, b) => b[1] - a[1])
        .forEach(([subject, count]) => {
          console.log(`  ${subject}: ${count} questions`);
        });
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

countRMEQuestions();