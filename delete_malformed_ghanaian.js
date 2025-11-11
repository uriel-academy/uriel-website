// delete_malformed_ghanaian.js
// Delete the malformed shortAnswer Ghanaian Language questions
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Fetching malformed Ghanaian Language questions...\n');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .where('type', '==', 'shortAnswer')
      .get();
    
    console.log(`Found ${snapshot.size} malformed questions to delete\n`);
    
    if (snapshot.empty) {
      console.log('No malformed questions found. Nothing to delete.');
      process.exit(0);
    }
    
    // Confirm deletion
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    const answer = await new Promise(resolve => {
      rl.question(`⚠️  Are you sure you want to delete ${snapshot.size} documents? (yes/no): `, resolve);
    });
    rl.close();
    
    if (answer.toLowerCase() !== 'yes') {
      console.log('Deletion cancelled.');
      process.exit(0);
    }
    
    console.log('\nDeleting malformed questions...');
    
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
    console.log(`✅ Successfully deleted ${totalDeleted} malformed questions`);
    console.log('='.repeat(60));
    
    // Verify remaining count
    const remaining = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .get();
    
    console.log(`\nRemaining Ghanaian Language questions: ${remaining.size}`);
    
    process.exit(0);
  } catch (e) {
    console.error('❌ Error during deletion:', e);
    process.exit(1);
  }
})();
