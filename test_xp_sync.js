const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testXPSync() {
  console.log('\n🔍 Testing XP Synchronization...\n');
  
  try {
    // Get a sample user
    const usersSnapshot = await db.collection('users')
      .where('totalXP', '>', 0)
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No users with XP found');
      return;
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log('📊 User Data:');
    console.log(`   User ID: ${userId}`);
    console.log(`   Total XP: ${userData.totalXP || 0}`);
    console.log(`   Display Name: ${userData.displayName || 'N/A'}`);
    
    // Check if rank info is stored
    if (userData.currentRank) {
      console.log(`   Current Rank: ${userData.currentRankName} (Rank #${userData.currentRank})`);
      console.log(`   Rank Image URL: ${userData.rankImageUrl || 'N/A'}`);
    }
    
    // Get rank from leaderboard service
    const xp = userData.totalXP || 0;
    const ranksSnapshot = await db.collection('leaderboardRanks')
      .where('minXP', '<=', xp)
      .where('maxXP', '>=', xp)
      .limit(1)
      .get();
    
    if (!ranksSnapshot.empty) {
      const rankData = ranksSnapshot.docs[0].data();
      console.log('\n🏆 Calculated Rank (from XP):');
      console.log(`   Rank: ${rankData.name} (Rank #${rankData.rank})`);
      console.log(`   XP Range: ${rankData.minXP} - ${rankData.maxXP}`);
      console.log(`   Image URL: ${rankData.imageUrl}`);
      
      // Check if URL is valid
      if (rankData.imageUrl && rankData.imageUrl.startsWith('https://')) {
        console.log('   ✅ Image URL is valid');
      } else {
        console.log('   ⚠️ Image URL may be invalid');
      }
    } else {
      console.log('\n❌ No rank found for this XP amount');
    }
    
    // Check XP transactions
    const xpTransactions = await db.collection('xp_transactions')
      .where('userId', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(5)
      .get();
    
    if (!xpTransactions.empty) {
      console.log('\n💰 Recent XP Transactions:');
      xpTransactions.forEach(doc => {
        const tx = doc.data();
        console.log(`   +${tx.xpAmount} XP from ${tx.source}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

testXPSync();
