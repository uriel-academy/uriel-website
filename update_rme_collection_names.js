const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updateRMECollectionNames() {
  try {
    console.log('🔄 Updating RME collection names to BECE RME format...\n');

    const snapshot = await db.collection('questionCollections')
      .where('subject', '==', 'religiousMoralEducation')
      .where('type', '==', 'topic')
      .get();

    console.log(`Found ${snapshot.size} RME topic collections\n`);

    let batch = db.batch();
    let batchCount = 0;
    let updateCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const currentName = data.name || '';

      // Update names that start with 'RME:' to 'BECE RME'
      if (currentName.startsWith('RME: ')) {
        const newName = 'BECE RME ' + currentName.substring(5);

        batch.update(doc.ref, { name: newName });
        batchCount++;
        updateCount++;

        console.log(`✅ Updated: ${currentName}`);
        console.log(`   → ${newName}\n`);

        // Commit batch every 500 operations (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`  💾 Committed batch of ${batchCount} operations`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }

    // Commit remaining operations
    if (batchCount > 0) {
      await batch.commit();
      console.log(`  💾 Committed final batch of ${batchCount} operations`);
    }

    console.log('\n' + '='.repeat(70));
    console.log('📊 UPDATE SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total RME collections updated: ${updateCount}`);
    console.log('='.repeat(70));

    console.log('\n✅ All RME topic collections now use BECE RME naming format!');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

updateRMECollectionNames();