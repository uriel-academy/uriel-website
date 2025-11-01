// Script to remove teachers from studentSummaries collection
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🧹 Cleaning up teachers from studentSummaries...\n');

async function cleanup() {
  try {
    // Get all teachers
    const teachersSnap = await db.collection('users').where('role', '==', 'teacher').get();
    const teacherIds = new Set(teachersSnap.docs.map(d => d.id));
    
    console.log(`📚 Found ${teacherIds.size} teachers to check`);
    
    // Check studentSummaries for any teacher entries
    const summariesSnap = await db.collection('studentSummaries').get();
    const toDelete = [];
    
    summariesSnap.docs.forEach(doc => {
      if (teacherIds.has(doc.id)) {
        toDelete.push(doc.id);
        const data = doc.data();
        console.log(`   🗑️  Will delete: ${data.firstName} ${data.lastName} (${doc.id})`);
      }
    });
    
    if (toDelete.length === 0) {
      console.log(`\n✅ No teachers found in studentSummaries. Nothing to clean up.`);
      process.exit(0);
      return;
    }
    
    console.log(`\n🧹 Deleting ${toDelete.length} teacher entries from studentSummaries...`);
    
    const batch = db.batch();
    toDelete.forEach(id => {
      batch.delete(db.collection('studentSummaries').doc(id));
    });
    
    await batch.commit();
    
    console.log(`✅ Successfully deleted ${toDelete.length} teacher entries`);
    console.log(`\n📊 Summary:`);
    console.log(`   - Removed ${toDelete.length} teachers from studentSummaries`);
    console.log(`   - Teacher dashboard will no longer show teacher data`);
    console.log(`   - Student count will be accurate`);
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

cleanup();
