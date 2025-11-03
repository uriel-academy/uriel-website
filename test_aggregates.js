const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function testAggregates() {
  const db = admin.firestore();
  
  // Get students
  const studentsSnap = await db.collection('users')
    .where('role', '==', 'student')
    .where('school', '==', 'Ave Maria')
    .get();
  
  console.log('Total students found:', studentsSnap.size);
  
  const studentIds = [];
  studentsSnap.forEach(doc => {
    studentIds.push(doc.id);
    const d = doc.data();
    console.log('Student:', d.firstName, d.lastName, 'Class:', d.class);
  });
  
  // Get studentSummaries
  if (studentIds.length > 0) {
    const summariesSnap = await db.collection('studentSummaries')
      .where(admin.firestore.FieldPath.documentId(), 'in', studentIds)
      .get();
    
    console.log('\nStudent summaries found:', summariesSnap.size);
    
    let totalXP = 0;
    let totalQuestions = 0;
    let totalAccuracy = 0;
    let countWithAccuracy = 0;
    const subjects = new Set();
    
    summariesSnap.forEach(doc => {
      const d = doc.data();
      console.log('\nSummary for:', d.firstName, d.lastName);
      console.log('  XP:', d.totalXP);
      console.log('  Questions:', d.totalQuestions);
      console.log('  Subjects:', d.subjectsCount);
      console.log('  Accuracy:', d.avgPercent);
      
      totalXP += d.totalXP || 0;
      totalQuestions += d.totalQuestions || 0;
      if (d.avgPercent && d.avgPercent > 0) {
        totalAccuracy += d.avgPercent;
        countWithAccuracy++;
      }
      if (d.subjectsCount) {
        subjects.add(d.subjectsCount);
      }
    });
    
    console.log('\n=== AGGREGATES ===');
    console.log('Total XP:', totalXP);
    console.log('Average XP:', totalXP / studentsSnap.size);
    console.log('Total Questions:', totalQuestions);
    console.log('Average Accuracy:', countWithAccuracy > 0 ? totalAccuracy / countWithAccuracy : 0);
    console.log('Total Subjects:', subjects.size);
  }
  
  await admin.app().delete();
}

testAggregates().catch(console.error);
