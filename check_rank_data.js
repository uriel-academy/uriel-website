const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRankImages() {
  console.log('\n🔍 Checking Rank Images and XP Sync...\n');
  
  try {
    // Get user with 425 XP
    const usersSnapshot = await db.collection('users')
      .where('totalXP', '==', 425)
      .limit(1)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('❌ No user with 425 XP found');
      return;
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log('📊 User with 425 XP:');
    console.log(`   User ID: ${userDoc.id}`);
    console.log(`   Total XP: ${userData.totalXP}`);
    
    // 425 XP = Rank 1 (Learner: 0-999 XP)
    console.log('\n🏆 Expected Rank: Learner (Rank #1)');
    console.log('   XP Range: 0 - 999');
    
    // Check Rank 1 in Firestore
    const rank1Doc = await db.collection('leaderboardRanks').doc('rank_1').get();
    
    if (rank1Doc.exists) {
      const rank1Data = rank1Doc.data();
      console.log('\n✅ Rank 1 Data from Firestore:');
      console.log(`   Name: ${rank1Data.name}`);
      console.log(`   Min XP: ${rank1Data.minXP}`);
      console.log(`   Max XP: ${rank1Data.maxXP}`);
      console.log(`   Image URL: ${rank1Data.imageUrl}`);
      
      // Verify URL
      if (rank1Data.imageUrl && rank1Data.imageUrl.includes('storage.googleapis.com')) {
        console.log('   ✅ Image URL is valid Firebase Storage URL');
      } else {
        console.log('   ⚠️ Image URL may not be valid');
      }
      
      // Check if 425 falls within range
      if (425 >= rank1Data.minXP && 425 <= rank1Data.maxXP) {
        console.log('   ✅ 425 XP correctly falls within Rank 1 range');
      } else {
        console.log('   ❌ 425 XP does NOT fall within Rank 1 range');
      }
    } else {
      console.log('\n❌ Rank 1 document not found in Firestore!');
    }
    
    // Check all ranks
    console.log('\n📋 Checking all 28 ranks...');
    for (let i = 1; i <= 28; i++) {
      const rankDoc = await db.collection('leaderboardRanks').doc(`rank_${i}`).get();
      if (rankDoc.exists) {
        const data = rankDoc.data();
        const hasImage = data.imageUrl && data.imageUrl.length > 0;
        console.log(`   Rank ${i} (${data.name}): ${data.minXP}-${data.maxXP} XP - Image: ${hasImage ? '✅' : '❌'}`);
      } else {
        console.log(`   Rank ${i}: ❌ Not found`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  
  process.exit(0);
}

checkRankImages();
