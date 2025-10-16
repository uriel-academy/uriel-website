const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testUserStatsLoad() {
  try {
    const userId = '1KyEco2NEDVJE2LK61sBuTpmQOj2'; // Test user ID

    console.log('🧪 Testing user stats loading...');
    console.log('User ID:', userId);
    console.log('---');

    // Simulate what _loadUserStats does
    console.log('📊 Querying quizzes collection...');

    const quizSnapshot = await db.collection('quizzes')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(100)
      .get();

    console.log(`✅ Query successful! Found ${quizSnapshot.docs.length} quiz documents`);

    if (quizSnapshot.docs.length === 0) {
      console.log('⚠️ No quiz data found - this would show 0% progress');
      return;
    }

    // Calculate stats like the app does
    let totalQuestions = 0;
    let totalCorrect = 0;

    for (const doc of quizSnapshot.docs) {
      const data = doc.data();
      const questions = data.totalQuestions || 0;
      const correct = data.correctAnswers || 0;

      totalQuestions += questions;
      totalCorrect += correct;

      console.log(`Quiz: ${data.subject} - ${correct}/${questions} (${data.percentage}%)`);
    }

    const overallProgress = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0;

    console.log('---');
    console.log('📈 Calculated Stats:');
    console.log(`   Questions Answered: ${totalQuestions}`);
    console.log(`   Overall Progress: ${overallProgress.toFixed(1)}%`);
    console.log(`   Current Streak: (would need activity dates to calculate)`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

testUserStatsLoad();