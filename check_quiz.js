const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQuizDocument() {
  try {
    const userId = '1KyEco2NEDVJE2LK61sBuTpmQOj2';
    const docId = 'QaYtAFaSEfogG6N57aJT';
    
    console.log('📊 Checking quiz document...');
    console.log('User ID:', userId);
    console.log('Document ID:', docId);
    console.log('---');
    
    // Get the specific document
    const docRef = db.collection('quizzes').doc(docId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      console.log('❌ Document does not exist!');
      return;
    }
    
    const data = doc.data();
    console.log('✅ Document found!');
    console.log('Document Data:', JSON.stringify(data, null, 2));
    console.log('---');
    
    // Check all quizzes for this user
    console.log('📋 Fetching all quizzes for user...');
    const userQuizzes = await db.collection('quizzes')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    console.log(`Found ${userQuizzes.docs.length} quizzes for user`);
    userQuizzes.docs.forEach((doc, index) => {
      const quiz = doc.data();
      console.log(`\nQuiz ${index + 1}:`);
      console.log('  ID:', doc.id);
      console.log('  Subject:', quiz.subject);
      console.log('  ExamType:', quiz.examType);
      console.log('  QuizType:', quiz.quizType);
      console.log('  Score:', `${quiz.correctAnswers}/${quiz.totalQuestions} (${quiz.percentage}%)`);
      console.log('  Timestamp:', quiz.timestamp ? quiz.timestamp.toDate() : 'null');
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkQuizDocument();
