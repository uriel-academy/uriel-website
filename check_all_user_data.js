const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUserData() {
  try {
    console.log('🔍 Checking user data in Firestore...\n');

    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.docs.length} user documents:`);

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const uid = userDoc.id;
      console.log(`\n👤 User: ${userData.email || uid}`);
      console.log(`   Name: ${userData.firstName} ${userData.lastName || ''}`);
      console.log(`   Role: ${userData.role || 'student'}`);
      console.log(`   Class: ${userData.class || 'Not set'}`);

      // Check quiz data for this user
      const quizzesSnapshot = await db.collection('quizzes')
        .where('userId', '==', uid)
        .get();

      console.log(`   Quizzes: ${quizzesSnapshot.docs.length}`);

      if (quizzesSnapshot.docs.length > 0) {
        let totalQuestions = 0;
        let totalCorrect = 0;

        for (const quizDoc of quizzesSnapshot.docs) {
          const quizData = quizDoc.data();
          totalQuestions += quizData.totalQuestions || 0;
          totalCorrect += quizData.correctAnswers || 0;
        }

        const accuracy = totalQuestions > 0 ? ((totalCorrect / totalQuestions) * 100).toFixed(1) : 0;
        console.log(`   Total Questions: ${totalQuestions}`);
        console.log(`   Total Correct: ${totalCorrect}`);
        console.log(`   Accuracy: ${accuracy}%`);
      }
    }

  } catch (error) {
    console.error('❌ Error checking user data:', error);
  }
}

checkUserData();