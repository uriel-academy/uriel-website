const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function removeFrenchCollections() {
    console.log('🗑️  Removing French Collections from App...\n');
    
    // Get all French collections (both MCQ and Theory)
    const snapshot = await db.collection('questionCollections')
        .where('subject', '==', 'french')
        .get();
    
    console.log(`Found ${snapshot.size} French collections\n`);
    
    let updated = 0;
    let errors = 0;
    
    for (const doc of snapshot.docs) {
        const data = doc.data();
        const type = data.questionType;
        const year = data.year;
        
        console.log(`Deactivating: ${year} ${type}`);
        
        try {
            await doc.ref.update({
                isActive: false,
                _deactivatedReason: 'French collections temporarily removed - to be reimplemented',
                _deactivatedDate: new Date().toISOString()
            });
            updated++;
        } catch (e) {
            console.error(`   ❌ Error updating ${doc.id}:`, e.message);
            errors++;
        }
    }
    
    console.log(`\n✅ Summary:`);
    console.log(`   Deactivated: ${updated}`);
    console.log(`   Errors: ${errors}`);
    console.log(`   Total: ${snapshot.size}`);
    console.log(`\n📝 Note: Collections are marked inactive, not deleted.`);
    console.log(`   You can reactivate them later by setting isActive: true`);
    
    process.exit(0);
}

removeFrenchCollections().catch(e => {
    console.error('❌ Error:', e);
    process.exit(1);
});
