const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function analyzeTeacherDashboardData() {
  console.log('=== Analyzing Teacher Dashboard Data ===\n');
  
  // Get teacher
  const teacherSnap = await db.collection('users').where('role', '==', 'teacher').limit(1).get();
  const teacherId = teacherSnap.docs[0].id;
  const teacherData = teacherSnap.docs[0].data();
  
  console.log('Teacher:', teacherData.firstName, teacherData.lastName);
  console.log('School:', teacherData.school || teacherData.schoolName);
  console.log('Class:', teacherData.class || teacherData.teachingGrade);
  console.log('\n');
  
  // Get students for this teacher
  const studentsSnap = await db.collection('studentSummaries')
    .where('teacherId', '==', teacherId)
    .get();
  
  console.log(`Found ${studentsSnap.size} students\n`);
  
  // Collect aggregate data
  let totalXP = 0;
  let totalQuestions = 0;
  let totalAccuracy = 0;
  let totalSubjects = 0;
  let studentsWithData = 0;
  const subjectPerformance = {};
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const studentId = doc.id;
    
    totalXP += data.totalXP || 0;
    totalQuestions += data.totalQuestions || 0;
    totalSubjects += data.subjectsCount || 0;
    
    // Get quizzes for subject breakdown
    const quizzesSnap = await db.collection('quizzes')
      .where('userId', '==', studentId)
      .get();
    
    quizzesSnap.docs.forEach(qDoc => {
      const qData = qDoc.data();
      const subject = qData.subject || qData.collectionName || 'Unknown';
      const percentage = qData.percentage || 0;
      
      if (!subjectPerformance[subject]) {
        subjectPerformance[subject] = { total: 0, count: 0, students: new Set() };
      }
      subjectPerformance[subject].total += percentage;
      subjectPerformance[subject].count += 1;
      subjectPerformance[subject].students.add(studentId);
    });
    
    if (data.avgPercent) {
      totalAccuracy += data.avgPercent;
      studentsWithData++;
    }
  }
  
  console.log('=== AGGREGATE METRICS ===');
  console.log('Total XP:', totalXP);
  console.log('Average XP per student:', (totalXP / studentsSnap.size).toFixed(0));
  console.log('Total Questions Answered:', totalQuestions);
  console.log('Average Questions per student:', (totalQuestions / studentsSnap.size).toFixed(0));
  console.log('Average Accuracy:', studentsWithData > 0 ? (totalAccuracy / studentsWithData).toFixed(1) + '%' : 'N/A');
  console.log('Average Subjects per student:', (totalSubjects / studentsSnap.size).toFixed(1));
  console.log('\n');
  
  console.log('=== SUBJECT PERFORMANCE ===');
  Object.keys(subjectPerformance).forEach(subject => {
    const data = subjectPerformance[subject];
    const avgPerformance = data.total / data.count;
    const studentCount = data.students.size;
    console.log(`${subject}:`);
    console.log(`  Students engaged: ${studentCount}`);
    console.log(`  Average performance: ${avgPerformance.toFixed(1)}%`);
    console.log(`  Total attempts: ${data.count}`);
  });
  
  process.exit(0);
}

analyzeTeacherDashboardData().catch(console.error);
