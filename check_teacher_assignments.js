const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkTeacherStudentAssignments() {
  console.log('🔍 Checking Teacher-Student Assignments\n');
  console.log('='.repeat(80));

  try {
    // Get all teachers
    const teachersSnapshot = await db.collection('users')
      .where('role', '==', 'teacher')
      .get();

    console.log(`\n📚 Found ${teachersSnapshot.size} teachers\n`);

    for (const teacherDoc of teachersSnapshot.docs) {
      const teacherId = teacherDoc.id;
      const teacherData = teacherDoc.data();
      
      console.log(`\n👨‍🏫 Teacher: ${teacherData.firstName} ${teacherData.lastName}`);
      console.log(`   Email: ${teacherData.email}`);
      console.log(`   School: ${teacherData.school || teacherData.schoolName || 'N/A'}`);
      console.log(`   Class: ${teacherData.teachingGrade || teacherData.grade || teacherData.class || 'N/A'}`);
      console.log(`   Teacher ID: ${teacherId}`);

      // Get students assigned to this teacher
      const studentsSnapshot = await db.collection('users')
        .where('role', '==', 'student')
        .where('teacherId', '==', teacherId)
        .get();

      console.log(`   Students: ${studentsSnapshot.size}`);
      
      if (studentsSnapshot.size > 0) {
        for (const studentDoc of studentsSnapshot.docs) {
          const studentData = studentDoc.data();
          console.log(`      - ${studentData.firstName} ${studentData.lastName} (${studentData.email})`);
          console.log(`        XP: ${studentData.totalXP || 0}, School: ${studentData.school || 'N/A'}, Grade: ${studentData.grade || studentData.class || 'N/A'}`);
        }
      }

      // Check studentSummaries for this teacher
      const summariesSnapshot = await db.collection('studentSummaries')
        .where('teacherId', '==', teacherId)
        .get();

      console.log(`   StudentSummaries: ${summariesSnapshot.size} entries`);
    }

    // Check students without teachers
    console.log('\n' + '='.repeat(80));
    console.log('\n🔍 Students WITHOUT Teachers:\n');

    const allStudentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();

    let orphanedCount = 0;
    for (const studentDoc of allStudentsSnapshot.docs) {
      const studentData = studentDoc.data();
      if (!studentData.teacherId) {
        orphanedCount++;
        console.log(`   ⚠️  ${studentData.firstName} ${studentData.lastName} (${studentData.email})`);
        console.log(`      School: ${studentData.school || 'N/A'}, Grade: ${studentData.grade || studentData.class || 'N/A'}`);
      }
    }

    console.log(`\n   Total students without teachers: ${orphanedCount}/${allStudentsSnapshot.size}`);
    console.log('\n' + '='.repeat(80));

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkTeacherStudentAssignments();
