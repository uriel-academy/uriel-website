const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateAveMariaXP() {
  try {
    console.log('🔍 Finding Ave Maria students...');
    
    // Get all students
    const studentsSnap = await db.collection('users')
      .where('role', '==', 'student')
      .get();
    
    const aveMariaStudents = studentsSnap.docs.filter(doc => {
      const school = doc.data().school || '';
      const normalizedSchool = school.toLowerCase().trim();
      return normalizedSchool.includes('ave maria') || normalizedSchool.includes('ave-maria');
    });
    
    console.log(`📊 Found ${aveMariaStudents.length} Ave Maria students`);
    
    for (const studentDoc of aveMariaStudents) {
      const studentId = studentDoc.id;
      const studentData = studentDoc.data();
      const name = studentData.name || studentData.displayName || 'Unknown';
      
      console.log(`\n👤 Processing: ${name} (${studentId})`);
      
      // Get all quizzes for this student
      const quizzesSnap = await db.collection('quizzes')
        .where('userId', '==', studentId)
        .get();
      
      let totalXP = 0;
      let totalQuestions = 0;
      let correctAnswers = 0;
      
      for (const quizDoc of quizzesSnap.docs) {
        const quizData = quizDoc.data();
        const questions = quizData.totalQuestions || 0;
        const correct = quizData.correctAnswers || 0;
        const percentage = quizData.percentage || 0;
        
        // Calculate XP for this quiz (same formula as the app)
        const quizXP = Math.floor(correct * 10); // 10 XP per correct answer
        
        totalXP += quizXP;
        totalQuestions += questions;
        correctAnswers += correct;
      }
      
      console.log(`   Quizzes: ${quizzesSnap.docs.length}`);
      console.log(`   Questions: ${totalQuestions}`);
      console.log(`   Correct: ${correctAnswers}`);
      console.log(`   Calculated XP: ${totalXP}`);
      console.log(`   Current XP in DB: ${studentData.xp || 0}`);
      
      if (totalXP !== studentData.xp) {
        console.log(`   ✏️  Updating XP from ${studentData.xp || 0} to ${totalXP}`);
        await db.collection('users').doc(studentId).update({
          xp: totalXP,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   ✅ Updated!`);
      } else {
        console.log(`   ✓ XP already correct`);
      }
    }
    
    console.log('\n✅ All Ave Maria student XP values updated!');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

updateAveMariaXP();
