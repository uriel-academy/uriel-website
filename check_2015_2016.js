const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkYear(year) {
    const snapshot = await db.collection('bece_mcq')
        .where('subject', '==', 'french')
        .where('year', '==', year)
        .get();
    
    const questions = [];
    snapshot.forEach(doc => {
        const data = doc.data();
        questions.push(data.questionNumber);
    });
    
    questions.sort((a, b) => a - b);
    
    console.log(`\n=== Year ${year}: ${questions.length}/40 questions ===`);
    console.log('Present:', questions.join(', '));
    
    const missing = [];
    for (let i = 1; i <= 40; i++) {
        if (!questions.includes(i)) {
            missing.push(i);
        }
    }
    if (missing.length > 0) {
        console.log('Missing:', missing.join(', '));
    }
}

async function main() {
    await checkYear('2015');
    await checkYear('2016');
    process.exit(0);
}

main();
