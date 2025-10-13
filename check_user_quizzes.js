const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUserQuizzes() {
  try {
    // Get the user with the most XP (likely the current user)
    const usersSnapshot = await db.collection('users')
      .orderBy('totalXP', 'desc')
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No users found');
      return;
    }
    
    const topUser = usersSnapshot.docs[0];
    const userData = topUser.data();
    const userId = topUser.id;
    
    console.log('=== TOP USER ===');
    console.log(`User ID: ${userId}`);
    console.log(`Display Name: ${userData.displayName || 'Not set'}`);
    console.log(`Total XP: ${userData.totalXP}`);
    console.log('');
    
    // Get all quizzes for this user
    console.log('=== USER QUIZZES ===');
    const quizzesSnapshot = await db.collection('quizzes')
      .where('userId', '==', userId)
      .get();
    
    console.log(`Found ${quizzesSnapshot.size} quizzes\n`);
    
    const byType = {};
    let totalAll = 0;
    
    quizzesSnapshot.forEach(doc => {
      const data = doc.data();
      const type = data.quizType || 'unknown';
      
      if (!byType[type]) {
        byType[type] = {
          count: 0,
          totalQuestions: 0,
          totalCorrect: 0,
          quizzes: []
        };
      }
      
      byType[type].count++;
      byType[type].totalQuestions += data.totalQuestions || 0;
      byType[type].totalCorrect += data.correctAnswers || 0;
      byType[type].quizzes.push({
        id: doc.id,
        questions: data.totalQuestions,
        correct: data.correctAnswers,
        xp: data.xpEarned
      });
      
      totalAll += data.totalQuestions || 0;
    });
    
    console.log('By Type:');
    for (const [type, stats] of Object.entries(byType)) {
      console.log(`\n${type}:`);
      console.log(`  Count: ${stats.count} quizzes`);
      console.log(`  Total Questions: ${stats.totalQuestions}`);
      console.log(`  Correct Answers: ${stats.totalCorrect}`);
      console.log(`  Accuracy: ${stats.totalQuestions > 0 ? ((stats.totalCorrect / stats.totalQuestions) * 100).toFixed(1) : 0}%`);
      console.log(`  Quizzes:`);
      stats.quizzes.forEach((q, i) => {
        console.log(`    ${i + 1}. ${q.id}: ${q.questions} questions, ${q.correct} correct, ${q.xp || 0} XP`);
      });
    }
    
    console.log(`\n=== OVERALL ===`);
    console.log(`Total Questions Across All Types: ${totalAll}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkUserQuizzes();
