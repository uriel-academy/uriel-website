const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyTeacherStudentMatching() {
  console.log('🔍 Verifying Teacher-Student Matching System\n');
  console.log('='.repeat(80));

  try {
    // Get all teachers
    const teachersSnapshot = await db.collection('users')
      .where('role', '==', 'teacher')
      .get();

    console.log(`\n📚 Found ${teachersSnapshot.size} teachers\n`);

    for (const teacherDoc of teachersSnapshot.docs) {
      const teacher = teacherDoc.data();
      const teacherId = teacherDoc.id;
      
      console.log(`\n${'='.repeat(80)}`);
      console.log(`👨‍🏫 Teacher: ${teacher.firstName} ${teacher.lastName}`);
      console.log(`   Email: ${teacher.email}`);
      console.log(`   School: ${teacher.school || teacher.schoolName || 'N/A'}`);
      console.log(`   Class: ${teacher.class || teacher.grade || teacher.teachingGrade || 'N/A'}`);
      console.log(`   Teacher ID: ${teacherId}`);

      // Check students subcollection
      const studentsSubCollection = await db.collection('users')
        .doc(teacherId)
        .collection('students')
        .get();

      console.log(`\n   📁 Students Subcollection: ${studentsSubCollection.size} entries`);
      
      if (studentsSubCollection.size > 0) {
        for (const studentRef of studentsSubCollection.docs) {
          const studentData = studentRef.data();
          console.log(`      - Student ID: ${studentRef.id}`);
          console.log(`        School: ${studentData.school || 'N/A'}, Grade: ${studentData.grade || studentData.class || 'N/A'}`);
        }
      }

      // Check studentSummaries for this teacher
      const summariesSnapshot = await db.collection('studentSummaries')
        .where('teacherId', '==', teacherId)
        .get();

      console.log(`\n   📊 StudentSummaries: ${summariesSnapshot.size} entries`);
      
      if (summariesSnapshot.size > 0) {
        for (const summary of summariesSnapshot.docs) {
          const data = summary.data();
          console.log(`      - ${data.firstName} ${data.lastName}`);
          console.log(`        School: ${data.school || 'N/A'}, Class: ${data.class || 'N/A'}`);
        }
      }

      // Check actual students with this teacherId
      const studentsSnapshot = await db.collection('users')
        .where('role', '==', 'student')
        .where('teacherId', '==', teacherId)
        .get();

      console.log(`\n   👥 Students with teacherId: ${studentsSnapshot.size} students`);
      
      if (studentsSnapshot.size > 0) {
        for (const student of studentsSnapshot.docs) {
          const studentData = student.data();
          console.log(`      - ${studentData.firstName} ${studentData.lastName}`);
          console.log(`        School: ${studentData.school || 'N/A'}, Grade: ${studentData.grade || studentData.class || 'N/A'}`);
        }
      }

      // Check for mismatches
      const teacherSchool = teacher.school || teacher.schoolName || '';
      const teacherClass = teacher.class || teacher.grade || teacher.teachingGrade || '';

      if (studentsSnapshot.size > 0) {
        for (const student of studentsSnapshot.docs) {
          const studentData = student.data();
          const studentSchool = studentData.school || '';
          const studentClass = studentData.grade || studentData.class || '';

          if (studentSchool !== teacherSchool || studentClass !== teacherClass) {
            console.log(`\n   ⚠️  MISMATCH DETECTED!`);
            console.log(`      Student: ${studentData.firstName} ${studentData.lastName}`);
            console.log(`      Student School/Class: ${studentSchool}/${studentClass}`);
            console.log(`      Teacher School/Class: ${teacherSchool}/${teacherClass}`);
          }
        }
      }
    }

    // Check for orphaned students (no teacher assigned)
    console.log(`\n\n${'='.repeat(80)}`);
    console.log('🔍 Checking for students without teachers...\n');

    const allStudentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();

    console.log(`Total students: ${allStudentsSnapshot.size}`);

    let orphanedCount = 0;
    for (const studentDoc of allStudentsSnapshot.docs) {
      const student = studentDoc.data();
      if (!student.teacherId) {
        orphanedCount++;
        if (orphanedCount <= 5) { // Show first 5 only
          console.log(`\n   ⚠️  No teacher: ${student.firstName} ${student.lastName}`);
          console.log(`      School: ${student.school || 'N/A'}, Grade: ${student.grade || student.class || 'N/A'}`);
        }
      }
    }

    if (orphanedCount > 5) {
      console.log(`\n   ... and ${orphanedCount - 5} more students without teachers`);
    }

    console.log(`\nTotal orphaned students: ${orphanedCount}`);

    // Check for orphaned studentSummaries
    console.log(`\n\n${'='.repeat(80)}`);
    console.log('🔍 Checking for orphaned studentSummaries...\n');

    const allSummaries = await db.collection('studentSummaries').get();
    console.log(`Total studentSummaries: ${allSummaries.size}`);

    let orphanedSummaries = 0;
    for (const summary of allSummaries.docs) {
      const data = summary.data();
      const studentId = summary.id;

      // Check if student still exists
      const studentDoc = await db.collection('users').doc(studentId).get();
      
      if (!studentDoc.exists) {
        orphanedSummaries++;
        console.log(`\n   ⚠️  Student document doesn't exist for summary: ${studentId}`);
        continue;
      }

      const studentData = studentDoc.data();
      
      // Check if teacherId matches
      if (studentData.teacherId !== data.teacherId) {
        console.log(`\n   ⚠️  teacherId mismatch for ${data.firstName} ${data.lastName}`);
        console.log(`      Student doc teacherId: ${studentData.teacherId}`);
        console.log(`      Summary teacherId: ${data.teacherId}`);
      }

      // Check if school/class matches
      const studentSchool = studentData.school || '';
      const studentClass = studentData.grade || studentData.class || '';
      const summarySchool = data.school || '';
      const summaryClass = data.class || '';

      if (studentSchool !== summarySchool || studentClass !== summaryClass) {
        console.log(`\n   ⚠️  School/Class mismatch for ${data.firstName} ${data.lastName}`);
        console.log(`      Student: ${studentSchool}/${studentClass}`);
        console.log(`      Summary: ${summarySchool}/${summaryClass}`);
      }
    }

    console.log(`\n${'='.repeat(80)}`);
    console.log('\n✅ Verification Complete!\n');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

verifyTeacherStudentMatching();
