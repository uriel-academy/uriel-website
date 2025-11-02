const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function normalizeText(text) {
  if (!text) return '';
  return text.toLowerCase().trim().replace(/\s+/g, ' ');
}

async function calculateRankFromXP(xp) {
  try {
    // Get all ranks and find the matching one (client-side filtering to avoid index issues)
    const ranksSnapshot = await db.collection('leaderboardRanks')
      .orderBy('rank')
      .get();
    
    for (const doc of ranksSnapshot.docs) {
      const rankData = doc.data();
      const minXP = rankData.minXP || 0;
      const maxXP = rankData.maxXP || 999999999;
      
      if (xp >= minXP && xp <= maxXP) {
        return {
          rank: rankData.rank,
          name: rankData.name,
          imageUrl: rankData.imageUrl,
        };
      }
    }
  } catch (e) {
    console.error('Error calculating rank:', e.message);
  }
  return { rank: null, name: null, imageUrl: null };
}

async function calculateStudentPerformance(studentId, studentData) {
  // Get XP from user document
  const totalXP = studentData.totalXP || studentData.xp || 0;
  
  // Get rank
  let rank = null;
  let rankName = null;
  if (studentData.currentRank) {
    rank = studentData.currentRank;
    rankName = studentData.currentRankName;
  } else {
    const rankData = await calculateRankFromXP(totalXP);
    rank = rankData.rank;
    rankName = rankData.name;
  }
  
  // Get quiz statistics
  const quizzesSnapshot = await db.collection('quizzes')
    .where('userId', '==', studentId)
    .get();
  
  const quizzes = quizzesSnapshot.docs;
  
  let totalQuestions = 0;
  let totalPercentage = 0;
  let quizzesWithPercentage = 0;
  const uniqueSubjects = new Set();
  
  for (const quiz of quizzes) {
    const quizData = quiz.data();
    totalQuestions += quizData.totalQuestions || 0;
    
    if (quizData.percentage != null && quizData.percentage > 0) {
      totalPercentage += quizData.percentage;
      quizzesWithPercentage++;
    }
    
    const subject = quizData.subject || quizData.collectionName;
    if (subject) {
      uniqueSubjects.add(subject);
    }
  }
  
  const avgPercent = quizzesWithPercentage > 0 
    ? totalPercentage / quizzesWithPercentage 
    : 0;
  
  return {
    totalXP,
    totalQuestions,
    subjectsCount: uniqueSubjects.size,
    avgPercent,
    rank,
    rankName,
  };
}

async function populateStudentSummaries() {
  console.log('🔄 Populating studentSummaries collection...\n');

  try {
    // Get all students
    const studentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();

    console.log(`Found ${studentsSnapshot.size} students\n`);

    let processedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;

    for (const studentDoc of studentsSnapshot.docs) {
      const studentId = studentDoc.id;
      const studentData = studentDoc.data();
      
      const teacherId = studentData.teacherId;
      
      if (!teacherId) {
        console.log(`⚠️  Skipped ${studentData.firstName} ${studentData.lastName} - no teacher assigned`);
        skippedCount++;
        continue;
      }

      try {
        // Calculate performance
        const performanceData = await calculateStudentPerformance(studentId, studentData);
        
        // Prepare summary document
        const summaryData = {
          teacherId: teacherId,
          firstName: studentData.firstName || '',
          lastName: studentData.lastName || '',
          displayName: studentData.displayName || `${studentData.firstName || ''} ${studentData.lastName || ''}`.trim(),
          email: studentData.email || '',
          school: studentData.school || '',
          class: studentData.grade || studentData.class || '',
          normalizedSchool: normalizeText(studentData.school),
          normalizedClass: normalizeText(studentData.grade || studentData.class),
          avatar: studentData.profileImageUrl || studentData.avatar || studentData.presetAvatar || null,
          // Performance metrics
          totalXP: performanceData.totalXP,
          totalQuestions: performanceData.totalQuestions,
          subjectsCount: performanceData.subjectsCount,
          avgPercent: performanceData.avgPercent,
          rank: performanceData.rank,
          rankName: performanceData.rankName,
          // Metadata
          lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Write to studentSummaries
        await db.collection('studentSummaries').doc(studentId).set(summaryData);
        
        console.log(`✅ ${studentData.firstName} ${studentData.lastName}: XP=${performanceData.totalXP}, Questions=${performanceData.totalQuestions}, Subjects=${performanceData.subjectsCount}, Rank=${performanceData.rankName || performanceData.rank || 'N/A'}`);
        processedCount++;
        
      } catch (error) {
        console.error(`❌ Error processing student ${studentId}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n' + '='.repeat(80));
    console.log('📊 Summary:');
    console.log(`   Processed: ${processedCount}`);
    console.log(`   Skipped: ${skippedCount}`);
    console.log(`   Errors: ${errorCount}`);
    console.log(`   Total: ${studentsSnapshot.size}`);
    console.log('='.repeat(80));

    process.exit(0);
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

populateStudentSummaries();
