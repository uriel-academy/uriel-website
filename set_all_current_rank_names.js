const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setCurrentRankNameForAllStudents() {
  try {
    console.log('🔍 Setting currentRankName for all students based on their XP...\n');
    
    // Get all students
    const studentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();
    
    // Get all ranks
    const ranksSnapshot = await db.collection('leaderboardRanks')
      .orderBy('rank')
      .get();
    
    const ranks = [];
    ranksSnapshot.forEach(doc => {
      ranks.push(doc.data());
    });
    
    let updatedCount = 0;
    
    for (const studentDoc of studentsSnapshot.docs) {
      const studentData = studentDoc.data();
      const xp = studentData.totalXP || 0;
      
      // Find matching rank
      let matchedRank = null;
      for (const rank of ranks) {
        if (xp >= rank.minXP && xp <= rank.maxXP) {
          matchedRank = rank;
          break;
        }
      }
      
      if (matchedRank) {
        await studentDoc.ref.update({
          currentRankName: matchedRank.name,
          currentRank: matchedRank.rank
        });
        console.log(`✅ ${studentData.displayName || studentData.email}: XP=${xp} → ${matchedRank.name}`);
        updatedCount++;
      } else {
        console.log(`⚠️  No rank found for ${studentData.displayName || studentData.email} (XP: ${xp})`);
      }
    }
    
    console.log(`\n📊 Updated ${updatedCount}/${studentsSnapshot.size} students`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

setCurrentRankNameForAllStudents();
