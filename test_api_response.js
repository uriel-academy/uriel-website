const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testGetClassAggregates() {
  console.log('=== Testing getClassAggregates API Response ===\n');
  
  // Get teacher info
  const teacherSnap = await db.collection('users').where('role', '==', 'teacher').limit(1).get();
  if (teacherSnap.empty) {
    console.log('No teachers found');
    return;
  }
  
  const teacherId = teacherSnap.docs[0].id;
  console.log('Testing with teacher ID:', teacherId);
  console.log('Teacher:', teacherSnap.docs[0].data().firstName, teacherSnap.docs[0].data().lastName);
  console.log('\n');
  
  // Simulate the API call by querying studentSummaries
  const summariesSnap = await db.collection('studentSummaries')
    .where('teacherId', '==', teacherId)
    .limit(1)
    .get();
  
  if (summariesSnap.empty) {
    console.log('No students found for this teacher');
    return;
  }
  
  const studentSummary = summariesSnap.docs[0].data();
  const studentId = summariesSnap.docs[0].id;
  
  console.log('Student Summary Data:');
  console.log('- totalXP:', studentSummary.totalXP);
  console.log('- totalQuestions:', studentSummary.totalQuestions);
  console.log('- subjectsCount:', studentSummary.subjectsCount);
  console.log('- avgPercent:', studentSummary.avgPercent);
  console.log('\n');
  
  // Get user data for rank
  const userDoc = await db.collection('users').doc(studentId).get();
  const userData = userDoc.data();
  console.log('User Data:');
  console.log('- currentRankName:', userData.currentRankName);
  console.log('- rankName:', userData.rankName);
  console.log('- profileImageUrl:', userData.profileImageUrl);
  console.log('\n');
  
  // Check quizzes for accuracy calculation
  const quizzesSnap = await db.collection('quizzes')
    .where('userId', '==', studentId)
    .limit(5)
    .get();
  
  console.log('Quiz Data (first 5):');
  let totalPercentage = 0;
  let count = 0;
  
  quizzesSnap.docs.forEach((qDoc, idx) => {
    const qData = qDoc.data();
    console.log(`Quiz ${idx + 1}:`);
    console.log('  - percentage:', qData.percentage);
    console.log('  - correctAnswers:', qData.correctAnswers);
    console.log('  - totalQuestions:', qData.totalQuestions);
    
    if (qData.percentage !== undefined) {
      totalPercentage += qData.percentage;
      count++;
    } else if (qData.correctAnswers !== undefined && qData.totalQuestions !== undefined) {
      const pct = (qData.correctAnswers / qData.totalQuestions) * 100;
      totalPercentage += pct;
      count++;
      console.log('  - calculated:', pct.toFixed(1) + '%');
    }
  });
  
  if (count > 0) {
    const avgAccuracy = totalPercentage / count;
    console.log('\nCalculated Average Accuracy:', avgAccuracy.toFixed(1) + '%');
  }
  
  process.exit(0);
}

testGetClassAggregates().catch(console.error);
