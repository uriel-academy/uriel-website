const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkEssays() {
  const snapshot = await db.collection('questions')
    .where('type', '==', 'essay')
    .get();

  console.log(`Found ${snapshot.docs.length} essay questions total\n`);
  
  // Group by subject
  const bySubject = {};
  snapshot.docs.forEach(doc => {
    const subject = doc.data().subject;
    bySubject[subject] = (bySubject[subject] || 0) + 1;
  });
  
  console.log('By subject:');
  Object.entries(bySubject).forEach(([subject, count]) => {
    console.log(`  ${subject}: ${count} questions`);
  });
  
  process.exit(0);
}

checkEssays();
