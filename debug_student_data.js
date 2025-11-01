const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function debugStudentData() {
  console.log('=== Checking Student Data ===\n');
  
  // Get a sample student from studentSummaries
  const summariesSnap = await db.collection('studentSummaries').limit(1).get();
  if (!summariesSnap.empty) {
    const doc = summariesSnap.docs[0];
    console.log('StudentSummary document:', doc.id);
    console.log(JSON.stringify(doc.data(), null, 2));
    console.log('\n');
    
    // Get the actual user document
    const userDoc = await db.collection('users').doc(doc.id).get();
    if (userDoc.exists) {
      console.log('User document:', userDoc.id);
      const userData = userDoc.data();
      console.log('User data fields:', Object.keys(userData));
      console.log('totalXP:', userData.totalXP);
      console.log('xp:', userData.xp);
      console.log('questionsSolved:', userData.questionsSolved);
      console.log('questionsSolvedCount:', userData.questionsSolvedCount);
      console.log('leaderboardRank:', userData.leaderboardRank);
      console.log('rank:', userData.rank);
      console.log('rankName:', userData.rankName);
      console.log('\n');
    }
    
    // Check quizzes for this student
    const quizzesSnap = await db.collection('quizzes')
      .where('userId', '==', doc.id)
      .limit(5)
      .get();
    
    console.log(`Found ${quizzesSnap.size} quizzes for this student`);
    if (!quizzesSnap.empty) {
      const quiz = quizzesSnap.docs[0].data();
      console.log('Sample quiz fields:', Object.keys(quiz));
      console.log('Quiz score:', quiz.score);
      console.log('Quiz total:', quiz.total);
      console.log('Quiz percent:', quiz.percent);
      console.log('Quiz subject:', quiz.subject || quiz.collectionName);
    }
  }
  
  process.exit(0);
}

debugStudentData().catch(console.error);
