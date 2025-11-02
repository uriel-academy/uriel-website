const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkSamRank() {
  try {
    // Get Sam Addo's user data
    const userSnapshot = await db.collection('users')
      .where('displayName', '==', 'Sam Addo')
      .get();
    
    if (userSnapshot.empty) {
      console.log('Sam Addo not found');
      return;
    }

    const userData = userSnapshot.docs[0].data();
    console.log('\n=== Sam Addo User Document ===');
    console.log('Display Name:', userData.displayName);
    console.log('XP:', userData.totalXP);
    console.log('Rank (number):', userData.rank);
    console.log('Rank Name:', userData.rankName);

    // Get studentSummaries data
    const summarySnapshot = await db.collection('studentSummaries')
      .where('studentId', '==', userSnapshot.docs[0].id)
      .get();
    
    if (!summarySnapshot.empty) {
      const summaryData = summarySnapshot.docs[0].data();
      console.log('\n=== Sam Addo Student Summary ===');
      console.log('Total XP:', summaryData.totalXP);
      console.log('Rank (number):', summaryData.rank);
      console.log('Rank Name:', summaryData.rankName);
    }

    // Get leaderboard ranks to show mapping
    const ranksSnapshot = await db.collection('leaderboardRanks')
      .orderBy('rank')
      .get();
    
    console.log('\n=== Leaderboard Ranks Mapping ===');
    ranksSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`Rank ${data.rank}: ${data.name} (${data.minXP}-${data.maxXP} XP)`);
    });

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkSamRank();
