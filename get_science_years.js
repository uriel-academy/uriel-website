const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function getScienceYears() {
    console.log('Fetching all Integrated Science questions...\n');
    
    const snapshot = await db.collection('questions')
        .where('subject', '==', 'Integrated Science')
        .where('type', '==', 'multipleChoice')
        .get();
    
    console.log(`Total Integrated Science MCQ questions: ${snapshot.size}`);
    
    // Group by year
    const byYear = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        const year = data.year || 'unknown';
        if (!byYear[year]) {
            byYear[year] = [];
        }
        byYear[year].push({
            questionNumber: data.questionNumber,
            hasImage: data.hasImage || false,
            imageUrl: data.imageUrl || null
        });
    });
    
    // Sort years
    const years = Object.keys(byYear).sort();
    
    console.log('\nQuestions by year:');
    for (const year of years) {
        const questions = byYear[year];
        const withImages = questions.filter(q => q.hasImage || q.imageUrl).length;
        console.log(`  ${year}: ${questions.length} questions (${withImages} with images)`);
    }
    
    // Check for years 2002-2022 specifically
    console.log('\n=== Years with images in DOCX files ===');
    const targetYears = ['2002', '2003', '2004', '2005', '2009', '2010', '2022'];
    for (const year of targetYears) {
        const count = byYear[year] ? byYear[year].length : 0;
        const status = count > 0 ? '✓ In database' : '✗ NOT in database';
        console.log(`  ${year}: ${status} (${count} questions)`);
    }
    
    process.exit(0);
}

getScienceYears().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
