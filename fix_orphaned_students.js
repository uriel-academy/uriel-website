const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixOrphanedStudents() {
  try {
    console.log('🔍 Finding orphaned students...\n');
    
    // Get all students with no teacher assigned
    const studentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();
    
    const orphanedStudents = [];
    const assignedStudents = [];
    
    studentsSnapshot.forEach(doc => {
      const data = doc.data();
      const teacherId = data.teacherId || data.teacher_id;
      
      if (!teacherId) {
        orphanedStudents.push({
          id: doc.id,
          name: data.displayName || `${data.firstName || ''} ${data.lastName || ''}`.trim() || 'Unknown',
          email: data.email,
          school: data.school || data.schoolName,
          grade: data.class || data.grade || data.className
        });
      } else {
        assignedStudents.push({
          id: doc.id,
          name: data.displayName || `${data.firstName || ''} ${data.lastName || ''}`.trim(),
          teacherId: teacherId
        });
      }
    });
    
    console.log(`📊 Found ${orphanedStudents.length} orphaned students`);
    console.log(`✅ Found ${assignedStudents.length} students with teachers\n`);
    
    if (orphanedStudents.length === 0) {
      console.log('✨ No orphaned students to fix!');
      process.exit(0);
    }
    
    // List orphaned students
    console.log('🔴 Orphaned Students:');
    orphanedStudents.forEach((student, idx) => {
      console.log(`${idx + 1}. ${student.name || 'Unnamed'}`);
      console.log(`   Email: ${student.email || 'No email'}`);
      console.log(`   School: ${student.school || 'Not set'}`);
      console.log(`   Grade: ${student.grade || 'Not set'}`);
      console.log('');
    });
    
    // Get the teacher (mark morrison)
    const teacherId = '2Uinubzgjhd9AWQQPfKOyK5D5a62';
    const teacherDoc = await db.collection('users').doc(teacherId).get();
    
    if (!teacherDoc.exists) {
      console.log('❌ Teacher not found!');
      process.exit(1);
    }
    
    const teacherData = teacherDoc.data();
    console.log(`\n👨‍🏫 Assigning to teacher: ${teacherData.firstName} ${teacherData.lastName}`);
    console.log(`   School: ${teacherData.school}`);
    console.log(`   Class: ${teacherData.teachingClass}\n`);
    
    // Assign all orphaned students to mark morrison
    let successCount = 0;
    let failCount = 0;
    
    for (const student of orphanedStudents) {
      try {
        // Update student document
        await db.collection('users').doc(student.id).update({
          teacherId: teacherId,
          teacher_id: teacherId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Add to teacher's students subcollection
        await db.collection('users').doc(teacherId)
          .collection('students').doc(student.id).set({
            studentId: student.id,
            addedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        
        console.log(`✅ Assigned: ${student.name}`);
        successCount++;
      } catch (error) {
        console.log(`❌ Failed to assign ${student.name}: ${error.message}`);
        failCount++;
      }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`   Success: ${successCount}`);
    console.log(`   Failed: ${failCount}`);
    console.log(`   Total: ${orphanedStudents.length}`);
    
    if (successCount > 0) {
      console.log(`\n🔄 Now run: node populate_student_summaries.js`);
      console.log(`   This will sync the newly assigned students to the teacher dashboard.`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixOrphanedStudents();
