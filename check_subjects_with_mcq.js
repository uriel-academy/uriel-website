const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkSubjects() {
  console.log('🔍 Checking which subjects have MCQ questions...\n');
  
  const questionsSnap = await db.collection('questions').get();
  console.log(`📊 Total questions in database: ${questionsSnap.size}\n`);
  
  const subjects = new Map();
  
  questionsSnap.docs.forEach(doc => {
    const data = doc.data();
    const subject = data.subject;
    if (subject) {
      subjects.set(subject, (subjects.get(subject) || 0) + 1);
    }
  });
  
  console.log('✅ Subjects with MCQ questions:\n');
  Array.from(subjects.entries())
    .sort((a, b) => a[0].localeCompare(b[0]))
    .forEach(([subject, count]) => {
      console.log(`   ${subject}: ${count} questions`);
    });
  
  console.log('\n📋 Subject list for code:');
  const subjectList = Array.from(subjects.keys()).sort();
  console.log(`   [${subjectList.map(s => `'${s}'`).join(', ')}]`);
  
  process.exit(0);
}

checkSubjects().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
