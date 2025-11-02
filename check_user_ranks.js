const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUserRankFields() {
  try {
    // Get Sam Addo and Kwaku Boateng by their IDs from studentSummaries
    const studentIds = ['1KyEco2NEDVJE2LK61sBuTpmQOj2', 'IRWQEhOtQFddUJ7LoGYGbKyGPeN2'];
    const users = await Promise.all(studentIds.map(id => db.collection('users').doc(id).get()));
    
    console.log('\n=== User Documents Rank Fields ===');
    users.forEach(doc => {
      if (doc.exists) {
        const data = doc.data();
        console.log(`\n${data.displayName || doc.id}:`);
        console.log('  - rank:', data.rank);
        console.log('  - rankName:', data.rankName);
        console.log('  - currentRankName:', data.currentRankName);
        console.log('  - leaderboardRank:', data.leaderboardRank);
      }
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkUserRankFields();
