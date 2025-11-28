const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function check2012() {
    const snapshot = await db.collection('bece_mcq')
        .where('subject', '==', 'french')
        .where('year', '==', '2012')
        .get();
    
    const questions = [];
    snapshot.forEach(doc => {
        const data = doc.data();
        questions.push(data.questionNumber);
    });
    
    questions.sort((a, b) => a - b);
    
    console.log('2012 Question Numbers:', questions);
    console.log('Total:', questions.length);
    
    // Check for gaps
    const missing = [];
    for (let i = 1; i <= 40; i++) {
        if (!questions.includes(i)) {
            missing.push(i);
        }
    }
    console.log('Missing:', missing);
    
    process.exit(0);
}

check2012();
