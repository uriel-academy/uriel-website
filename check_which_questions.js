const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkQuestions() {
    for (const year of ['2024', '2025']) {
        console.log(`\n=== Year ${year} ===`);
        
        const snapshot = await db.collection('bece_mcq')
            .where('subject', '==', 'french')
            .where('year', '==', year)
            .get();
        
        const numbers = snapshot.docs.map(doc => doc.data().questionNumber).sort((a, b) => a - b);
        console.log(`Total: ${numbers.length} questions`);
        console.log(`Question numbers: ${numbers.join(', ')}`);
        
        // Find missing
        const missing = [];
        for (let i = 1; i <= 40; i++) {
            if (!numbers.includes(i)) {
                missing.push(i);
            }
        }
        console.log(`Missing (${missing.length}): ${missing.join(', ')}`);
    }
    
    process.exit(0);
}

checkQuestions().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
