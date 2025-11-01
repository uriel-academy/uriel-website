// Script to clean up stale classAggregates documents
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🧹 Cleaning up stale classAggregates documents...\n');

async function cleanup() {
  try {
    // Delete the stale documents
    const toDelete = ['ave_maria_form_1', 'ave_maria_jhs_form_1'];
    
    console.log('🗑️  Deleting stale documents:');
    for (const docId of toDelete) {
      await db.collection('classAggregates').doc(docId).delete();
      console.log(`   ✓ Deleted: ${docId}`);
    }
    
    console.log('\n✅ Cleanup complete!');
    console.log('\n📊 Remaining document:');
    const doc = await db.collection('classAggregates').doc('ave_maria_1').get();
    if (doc.exists) {
      const data = doc.data();
      console.log(`   ID: ${doc.id}`);
      console.log(`   Total Students: ${data.totalStudents}`);
      console.log(`   Total XP: ${data.totalXP}`);
      console.log(`   Avg XP: ${data.totalStudents > 0 ? (data.totalXP / data.totalStudents) : 0}`);
    }
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

cleanup();
