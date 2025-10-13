const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQuizTypes() {
  try {
    console.log('Fetching quizzes...');
    
    const quizzesSnapshot = await db.collection('quizzes')
      .limit(50)
      .get();
    
    console.log(`\nFound ${quizzesSnapshot.size} quizzes\n`);
    
    const quizTypes = new Set();
    const quizTypeExamples = {};
    
    quizzesSnapshot.forEach(doc => {
      const data = doc.data();
      const quizType = data.quizType;
      
      if (quizType) {
        quizTypes.add(quizType);
        
        if (!quizTypeExamples[quizType]) {
          quizTypeExamples[quizType] = {
            id: doc.id,
            totalQuestions: data.totalQuestions,
            correctAnswers: data.correctAnswers,
            xpEarned: data.xpEarned,
            userId: data.userId
          };
        }
      }
    });
    
    console.log('=== UNIQUE QUIZ TYPES FOUND ===');
    Array.from(quizTypes).sort().forEach(type => {
      console.log(`- "${type}"`);
      const example = quizTypeExamples[type];
      console.log(`  Example: ${example.id}`);
      console.log(`  Questions: ${example.totalQuestions}, Correct: ${example.correctAnswers}, XP: ${example.xpEarned}`);
      console.log(`  User: ${example.userId}`);
      console.log('');
    });
    
    // Count per type
    console.log('\n=== COUNTS PER TYPE ===');
    for (const type of quizTypes) {
      const count = await db.collection('quizzes')
        .where('quizType', '==', type)
        .count()
        .get();
      console.log(`${type}: ${count.data().count} quizzes`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkQuizTypes();
