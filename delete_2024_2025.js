const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteYears() {
    const years = ['2024', '2025'];
    
    for (const year of years) {
        console.log(`\nDeleting questions for year ${year}...`);
        
        const snapshot = await db.collection('bece_mcq')
            .where('subject', '==', 'french')
            .where('year', '==', year)
            .get();
        
        console.log(`Found ${snapshot.size} questions to delete`);
        
        const batch = db.batch();
        snapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
        });
        
        await batch.commit();
        console.log(`Deleted ${snapshot.size} questions from ${year}`);
    }
    
    console.log('\nDeletion complete');
    process.exit(0);
}

deleteYears().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
