const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkFrenchMCQ() {
    console.log('Checking French MCQ questions...\n');
    
    // Check all French questions
    const allFrench = await db.collection('questions')
        .where('subject', '==', 'french')
        .limit(100)
        .get();
    
    console.log(`Total French questions (sample): ${allFrench.size}`);
    
    const types = {};
    allFrench.forEach(doc => {
        const type = doc.data().type;
        types[type] = (types[type] || 0) + 1;
    });
    
    console.log('\nFrench questions by type:');
    Object.entries(types).forEach(([type, count]) => {
        console.log(`  ${type}: ${count}`);
    });
    
    process.exit(0);
}

checkFrenchMCQ().catch(e => {
    console.error('Error:', e);
    process.exit(1);
});
