const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMixedSubjects() {
  try {
    console.log('🔍 Checking for mixed subjects in RME...');

    // Check RME questions that might have CAD content
    const query = db.collection('questions')
      .where('subject', '==', 'religiousMoralEducation')
      .where('year', 'in', ['2024', '2025']);

    const snapshot = await query.get();

    console.log(`📊 Total RME 2024/2025: ${snapshot.docs.length}`);

    let cadLike = 0;
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const text = data.questionText?.toLowerCase() || '';
      if (text.includes('batik') || text.includes('appliqué') || text.includes('crocheting') || text.includes('stencil') || text.includes('palette knife')) {
        cadLike++;
        console.log(`⚠️  CAD-like in RME: ${data.questionText?.substring(0, 100)}...`);
      }
    });

    console.log(`📋 CAD-like questions in RME: ${cadLike}`);

    // Also check if there are RME questions in CAD subject
    const cadQuery = db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('year', 'in', ['2024', '2025']);

    const cadSnapshot = await cadQuery.get();
    console.log(`📊 CAD 2024/2025: ${cadSnapshot.docs.length}`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkMixedSubjects();