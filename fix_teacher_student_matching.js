const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function normalizeText(text) {
  if (!text) return '';
  return text.toLowerCase().replace(/[^a-z0-9]/g, '').trim();
}

async function fixTeacherStudentMatching() {
  console.log('🔧 Fixing Teacher-Student Matching...\n');

  try {
    // Get all teachers
    const teachersSnapshot = await db.collection('users')
      .where('role', '==', 'teacher')
      .get();

    console.log(`Found ${teachersSnapshot.size} teachers\n`);

    for (const teacherDoc of teachersSnapshot.docs) {
      const teacher = teacherDoc.data();
      const teacherId = teacherDoc.id;
      
      const teacherSchool = teacher.school || teacher.schoolName || '';
      const teacherClass = teacher.class || teacher.grade || teacher.teachingGrade || '';

      console.log(`\n${'='.repeat(80)}`);
      console.log(`👨‍🏫 Teacher: ${teacher.firstName} ${teacher.lastName}`);
      console.log(`   School: ${teacherSchool}`);
      console.log(`   Class: ${teacherClass}`);

      if (!teacherSchool || !teacherClass) {
        console.log('   ⚠️  Skipping - missing school or class');
        continue;
      }

      // Find matching students
      const studentsSnapshot = await db.collection('users')
        .where('role', '==', 'student')
        .get();

      const normalizedTeacherSchool = normalizeText(teacherSchool);
      const normalizedTeacherClass = normalizeText(teacherClass);

      let matchedCount = 0;
      const batch = db.batch();

      for (const studentDoc of studentsSnapshot.docs) {
        const student = studentDoc.data();
        const studentId = studentDoc.id;
        
        const studentSchool = student.school || '';
        const studentClass = student.grade || student.class || '';

        const normalizedStudentSchool = normalizeText(studentSchool);
        const normalizedStudentClass = normalizeText(studentClass);

        // Check if school and class match (normalized)
        if (normalizedStudentSchool === normalizedTeacherSchool && 
            normalizedStudentClass === normalizedTeacherClass) {
          
          matchedCount++;
          console.log(`\n   ✅ Matching: ${student.firstName} ${student.lastName}`);
          console.log(`      Student School/Class: ${studentSchool}/${studentClass}`);

          // Update student document
          batch.update(db.collection('users').doc(studentId), {
            teacherId: teacherId,
            teacherAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Add to teacher's students subcollection
          batch.set(
            db.collection('users').doc(teacherId).collection('students').doc(studentId),
            {
              firstName: student.firstName || '',
              lastName: student.lastName || '',
              email: student.email || '',
              school: studentSchool,
              grade: studentClass,
              linkedAt: admin.firestore.FieldValue.serverTimestamp(),
              autoAssigned: true,
            }
          );

          // Add to studentSummaries with full performance data
          batch.set(
            db.collection('studentSummaries').doc(studentId),
            {
              teacherId: teacherId,
              firstName: student.firstName || '',
              lastName: student.lastName || '',
              displayName: `${student.firstName || ''} ${student.lastName || ''}`.trim(),
              email: student.email || '',
              school: studentSchool,
              class: studentClass,
              normalizedSchool: normalizedStudentSchool,
              normalizedClass: normalizedStudentClass,
              // Include performance data from user document
              totalXP: student.totalXP || student.xp || 0,
              totalQuestions: student.totalQuestions || student.questionsSolved || 0,
              subjectsCount: student.subjectsCount || student.subjectsSolved || 0,
              avgPercent: student.avgPercent || student.accuracy || 0,
              avatar: student.profileImageUrl || student.avatar || student.presetAvatar || null,
              rank: student.currentRankName || student.rankName || student.rank || null,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            }
          );
        }
      }

      if (matchedCount > 0) {
        await batch.commit();
        console.log(`\n   💾 Saved ${matchedCount} student assignments`);
      } else {
        console.log(`\n   ℹ️  No matching students found`);
      }
    }

    console.log(`\n${'='.repeat(80)}`);
    console.log('\n✅ Matching Complete!\n');

    // Run verification
    console.log('Running verification...\n');
    const verifySnapshot = await db.collection('studentSummaries').get();
    console.log(`Total studentSummaries: ${verifySnapshot.size}`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

fixTeacherStudentMatching();
