const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixKwakuRank() {
  try {
    const kwakuId = 'IRWQEhOtQFddUJ7LoGYGbKyGPeN2';
    
    // Get Kwaku's XP
    const userDoc = await db.collection('users').doc(kwakuId).get();
    const xp = userDoc.data().totalXP || 0;
    
    console.log(`Kwaku XP: ${xp}`);
    
    // Get the rank for this XP
    const ranksSnap = await db.collection('leaderboardRanks')
      .orderBy('rank')
      .get();
    
    let rankName = null;
    ranksSnap.forEach(doc => {
      const data = doc.data();
      if (xp >= data.minXP && xp <= data.maxXP) {
        rankName = data.name;
        console.log(`Matched rank: ${data.rank} - ${data.name} (${data.minXP}-${data.maxXP} XP)`);
      }
    });
    
    if (rankName) {
      await db.collection('users').doc(kwakuId).update({
        currentRankName: rankName
      });
      console.log(`✅ Updated Kwaku's currentRankName to: ${rankName}`);
    } else {
      console.log('❌ No rank found for this XP');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

fixKwakuRank();
