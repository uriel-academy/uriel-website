// delete_ga_asante_twi.js
// Delete all Ga and Asante Twi questions
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));

const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Deleting Ga and Asante Twi questions...\n');
    
    // Delete Ga questions
    const gaSnapshot = await db.collection('questions')
      .where('subject', '==', 'ga')
      .get();
    
    console.log(`Found ${gaSnapshot.size} Ga questions to delete`);
    
    let batch = db.batch();
    let count = 0;
    
    for (const doc of gaSnapshot.docs) {
      batch.delete(doc.ref);
      count++;
      
      if (count >= 100) {
        await batch.commit();
        console.log(`Deleted ${count} Ga questions`);
        batch = db.batch();
        count = 0;
      }
    }
    
    if (count > 0) {
      await batch.commit();
      console.log(`Deleted final ${count} Ga questions`);
    }
    
    // Delete Asante Twi questions
    const asanteTwiSnapshot = await db.collection('questions')
      .where('subject', '==', 'asanteTwi')
      .get();
    
    console.log(`Found ${asanteTwiSnapshot.size} Asante Twi questions to delete`);
    
    batch = db.batch();
    count = 0;
    
    for (const doc of asanteTwiSnapshot.docs) {
      batch.delete(doc.ref);
      count++;
      
      if (count >= 100) {
        await batch.commit();
        console.log(`Deleted ${count} Asante Twi questions`);
        batch = db.batch();
        count = 0;
      }
    }
    
    if (count > 0) {
      await batch.commit();
      console.log(`Deleted final ${count} Asante Twi questions`);
    }
    
    console.log('\n✅ Deletion complete!');
    console.log(`Total deleted: ${gaSnapshot.size + asanteTwiSnapshot.size} questions`);
    
    process.exit(0);
  } catch (e) {
    console.error('❌ Error during deletion:', e);
    process.exit(1);
  }
})();
