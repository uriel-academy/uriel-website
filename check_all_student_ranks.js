const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAllStudentRanks() {
  try {
    // Get all 8 students
    const studentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .where('teacherId', '==', '2Uinubzgjhd9AWQQPfKOyK5D5a62')
      .get();
    
    console.log('\n=== All Students Rank Fields ===\n');
    
    for (const doc of studentsSnapshot.docs) {
      const data = doc.data();
      console.log(`${data.displayName || 'Unknown'}:`);
      console.log(`  - ID: ${doc.id}`);
      console.log(`  - Email: ${data.email}`);
      console.log(`  - XP: ${data.totalXP || 0}`);
      console.log(`  - rank: ${data.rank}`);
      console.log(`  - rankName: ${data.rankName}`);
      console.log(`  - currentRankName: ${data.currentRankName}`);
      console.log(`  - leaderboardRank: ${data.leaderboardRank}`);
      console.log('');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkAllStudentRanks();
