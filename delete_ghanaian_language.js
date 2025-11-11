// delete_ghanaian_language.js
// Delete all ghanaianLanguage questions (will be replaced with ga and asanteTwi)
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Fetching ghanaianLanguage questions to delete...\n');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .get();
    
    console.log(`Found ${snapshot.size} ghanaianLanguage questions to delete\n`);
    
    if (snapshot.empty) {
      console.log('No ghanaianLanguage questions found. Nothing to delete.');
      process.exit(0);
    }
    
    console.log('Deleting questions...');
    
    const batch = db.batch();
    let batchCount = 0;
    let totalDeleted = 0;
    
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      batchCount++;
      
      if (batchCount >= 500) {
        await batch.commit();
        totalDeleted += batchCount;
        console.log(`Deleted ${totalDeleted} questions...`);
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
      totalDeleted += batchCount;
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`✅ Successfully deleted ${totalDeleted} ghanaianLanguage questions`);
    console.log('='.repeat(60));
    
    process.exit(0);
  } catch (e) {
    console.error('❌ Error during deletion:', e);
    process.exit(1);
  }
})();
