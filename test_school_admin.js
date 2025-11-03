// Test script to verify school admin pages
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const functions = admin.functions();

async function testSchoolAdmin() {
  console.log('Testing School Admin Setup...\n');
  
  // 1. Check school admin user
  console.log('1. Checking school admin user...');
  const userDoc = await db.collection('users').doc('yJWU7OQgNXTWIA5TMZ7lcOR7tso2').get();
  const userData = userDoc.data();
  console.log(`   User: ${userData.displayName || userData.email}`);
  console.log(`   Role: ${userData.role}`);
  console.log(`   School: ${userData.school}`);
  console.log('   ✓ School admin user exists\n');
  
  // 2. Check students in school
  console.log('2. Checking students in school...');
  const studentsSnap = await db.collection('users')
    .where('role', '==', 'student')
    .where('school', '==', userData.school)
    .get();
  console.log(`   Found ${studentsSnap.size} students in ${userData.school}`);
  studentsSnap.docs.forEach(doc => {
    const student = doc.data();
    console.log(`   - ${student.displayName || student.email} (${student.class || 'No class'})`);
  });
  console.log('   ✓ Students found\n');
  
  // 3. Check student summaries
  console.log('3. Checking student summaries...');
  const studentIds = studentsSnap.docs.map(d => d.id);
  for (const studentId of studentIds) {
    const summaryDoc = await db.collection('studentSummaries').doc(studentId).get();
    if (summaryDoc.exists) {
      const summary = summaryDoc.data();
      console.log(`   - ${studentId}: XP=${summary.totalXP}, Questions=${summary.totalQuestions}, Accuracy=${summary.avgPercent}%`);
    } else {
      console.log(`   - ${studentId}: NO SUMMARY`);
    }
  }
  console.log('   ✓ Student summaries checked\n');
  
  // 4. Test getSchoolAggregates (for dashboard)
  console.log('4. Testing getSchoolAggregates function (dashboard)...');
  try {
    const result = await admin.functions().httpsCallable('getSchoolAggregates')({
      schoolName: userData.school
    });
    console.log(`   Total Students: ${result.data.totalStudents}`);
    console.log(`   Total Teachers: ${result.data.totalTeachers}`);
    console.log(`   Total XP: ${result.data.totalXP}`);
    console.log(`   Total Questions: ${result.data.totalQuestions}`);
    console.log('   ✓ getSchoolAggregates works\n');
  } catch (error) {
    console.error(`   ✗ getSchoolAggregates failed: ${error.message}\n`);
  }
  
  // 5. Check if getSchoolStudents function exists
  console.log('5. Checking getSchoolStudents function (students page)...');
  const functionsListOutput = await admin.functions().list();
  const hasGetSchoolStudents = functionsListOutput.some(f => f.includes('getSchoolStudents'));
  if (hasGetSchoolStudents) {
    console.log('   ✓ getSchoolStudents function exists');
  } else {
    console.log('   ✗ getSchoolStudents function NOT FOUND - needs deployment');
  }
  
  console.log('\nTest complete!');
  process.exit(0);
}

testSchoolAdmin().catch(error => {
  console.error('Test failed:', error);
  process.exit(1);
});
