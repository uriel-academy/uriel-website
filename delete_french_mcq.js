const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function deleteFrenchMCQ() {
    console.log('Deleting existing French MCQ questions...\n');
    
    const snapshot = await db.collection('questions')
        .where('subject', '==', 'french')
        .where('type', '==', 'multipleChoice')
        .get();
    
    console.log(`Found ${snapshot.size} French MCQ questions to delete`);
    
    const batch = db.batch();
    let count = 0;
    
    snapshot.forEach(doc => {
        batch.delete(doc.ref);
        count++;
        
        // Firestore batch limit is 500
        if (count % 500 === 0) {
            console.log(`Batching ${count} deletions...`);
        }
    });
    
    await batch.commit();
    console.log(`✓ Deleted ${count} questions`);
    
    process.exit(0);
}

deleteFrenchMCQ().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
