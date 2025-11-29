const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixFrenchMCQCollections() {
    console.log('🔧 Fixing French MCQ Collections...\n');
    
    // Get all French MCQ collections
    const snapshot = await db.collection('questionCollections')
        .where('subject', '==', 'french')
        .where('questionType', '==', 'multipleChoice')
        .get();
    
    console.log(`Found ${snapshot.size} French MCQ collections\n`);
    
    let updated = 0;
    let errors = 0;
    
    for (const doc of snapshot.docs) {
        const data = doc.data();
        const questionIds = data.questionIds || [];
        
        if (questionIds.length === 0) {
            console.log(`⚠️  ${doc.id}: No questionIds, skipping`);
            continue;
        }
        
        // Check if first question exists
        const firstQuestionId = questionIds[0];
        const questionDoc = await db.collection('questions').doc(firstQuestionId).get();
        
        if (!questionDoc.exists) {
            console.log(`❌ ${data.year}: Questions missing (${questionIds.length} IDs), marking inactive`);
            
            try {
                await doc.ref.update({
                    isActive: false,
                    _deactivatedReason: 'Questions not imported yet',
                    _deactivatedDate: new Date().toISOString()
                });
                updated++;
            } catch (e) {
                console.error(`   Error updating ${doc.id}:`, e.message);
                errors++;
            }
        } else {
            console.log(`✅ ${data.year}: Questions exist, keeping active`);
        }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`   Updated: ${updated}`);
    console.log(`   Errors: ${errors}`);
    console.log(`   Total: ${snapshot.size}`);
    
    process.exit(0);
}

fixFrenchMCQCollections().catch(e => {
    console.error('❌ Error:', e);
    process.exit(1);
});
