const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateICTCollectionNames() {
  try {
    console.log('🔄 Updating ICT collection names to BECE ICT format...\n');
    
    const snapshot = await db.collection('questionCollections')
      .where('subject', '==', 'ict')
      .get();
    
    console.log(`Found ${snapshot.size} ICT collections\n`);
    
    let batch = db.batch();
    let batchCount = 0;
    let updateCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const currentName = data.name || '';
      
      // Update names that start with 'ICT:' to 'BECE ICT'
      if (currentName.startsWith('ICT: ')) {
        const newName = 'BECE ICT ' + currentName.substring(5);
        
        batch.update(doc.ref, { name: newName });
        batchCount++;
        updateCount++;
        
        console.log(`✅ Updated: ${currentName}`);
        console.log(`   → ${newName}\n`);
        
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`💾 Committed batch of ${batchCount} updates\n`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }

    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`💾 Committed final batch of ${batchCount} updates\n`);
    }

    console.log('='.repeat(60));
    console.log(`✅ Updated ${updateCount} collection names`);
    console.log('='.repeat(60));
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

updateICTCollectionNames();
