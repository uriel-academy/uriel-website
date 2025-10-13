const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkTriviaStructure() {
  try {
    console.log('🔍 Checking trivia question structure in questions collection\n');
    
    const snapshot = await db.collection('questions')
      .where('examType', '==', 'trivia')
      .where('subject', '==', 'trivia')
      .limit(3)
      .get();
    
    console.log(`Found ${snapshot.size} trivia questions in "questions" collection\n`);
    
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n--- Question ${index + 1} (${doc.id}) ---`);
      console.log('All fields:', Object.keys(data).join(', '));
      console.log('\nField values:');
      console.log('  question:', data.question?.substring(0, 60) || 'MISSING');
      console.log('  options:', data.options || 'MISSING');
      console.log('  correctAnswer:', data.correctAnswer || 'MISSING');
      console.log('  category:', data.category || 'MISSING');
      console.log('  triviaCategory:', data.triviaCategory || 'MISSING');
      console.log('  subject:', data.subject || 'MISSING');
      console.log('  examType:', data.examType || 'MISSING');
      console.log('  isActive:', data.isActive);
      console.log('  type:', data.type || 'MISSING');
      console.log('  difficulty:', data.difficulty || 'MISSING');
      console.log('  explanation:', data.explanation ? 'Present' : 'MISSING');
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkTriviaStructure();
