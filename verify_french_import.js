const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyFrenchImport() {
    console.log('Verifying French MCQ import...\n');
    
    const snapshot = await db.collection('questions')
        .where('subject', '==', 'french')
        .where('type', '==', 'multipleChoice')
        .get();
    
    console.log(`Total French MCQ questions: ${snapshot.size}\n`);
    
    // Group by year
    const byYear = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        const year = data.year;
        if (!byYear[year]) {
            byYear[year] = [];
        }
        byYear[year].push({
            questionNumber: data.questionNumber,
            question: data.question.substring(0, 60) + '...',
            correctAnswer: data.correctAnswer
        });
    });
    
    // Display
    for (const year of Object.keys(byYear).sort()) {
        console.log(`=== ${year} ===`);
        console.log(`Questions: ${byYear[year].length}`);
        
        // Show first 3
        byYear[year].slice(0, 3).forEach(q => {
            console.log(`  Q${q.questionNumber}: ${q.question} [Answer: ${q.correctAnswer}]`);
        });
        console.log();
    }
    
    process.exit(0);
}

verifyFrenchImport().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
