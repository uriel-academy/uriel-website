const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyComplete() {
    console.log('=== FRENCH MCQ IMPORT VERIFICATION ===\n');
    
    // Count by year
    const snapshot = await db.collection('bece_mcq')
        .where('subject', '==', 'french')
        .get();
    
    console.log(`✓ Total French MCQ Questions: ${snapshot.size}`);
    console.log(`✓ Expected: 760 questions (19 years × 40)`);
    console.log(`✓ Status: ${snapshot.size === 760 ? 'COMPLETE ✅' : 'INCOMPLETE ❌'}\n`);
    
    // Group by year
    const byYear = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        if (!byYear[data.year]) {
            byYear[data.year] = 0;
        }
        byYear[data.year]++;
    });
    
    const years = Object.keys(byYear).sort();
    console.log('Questions by Year:');
    years.forEach(year => {
        const count = byYear[year];
        const status = count === 40 ? '✓' : '✗';
        console.log(`  ${status} ${year}: ${count}/40`);
    });
    
    // Check for missing years
    console.log('\nYear Coverage:');
    const expectedYears = [
        ...Array.from({length: 17}, (_, i) => (2000 + i).toString()), // 2000-2016
        '2024', '2025'
    ];
    
    const missingYears = expectedYears.filter(y => !years.includes(y));
    if (missingYears.length > 0) {
        console.log(`  ✗ Missing years: ${missingYears.join(', ')}`);
    } else {
        console.log(`  ✓ All expected years present`);
    }
    
    // Sample a few questions
    console.log('\n=== Sample Questions ===');
    
    const samples = [
        { year: '2015', qNum: 26 }, // Special case Q26
        { year: '2024', qNum: 1 },  // 2024 format
        { year: '2012', qNum: 11 }, // Inline table format
    ];
    
    for (const sample of samples) {
        const doc = await db.collection('bece_mcq')
            .where('subject', '==', 'french')
            .where('year', '==', sample.year)
            .where('questionNumber', '==', sample.qNum)
            .get();
        
        if (!doc.empty) {
            const q = doc.docs[0].data();
            console.log(`\n${sample.year} Q${sample.qNum}:`);
            console.log(`  "${q.question.substring(0, 60)}..."`);
            console.log(`  Options: ${q.options.length}`);
            console.log(`  Answer: ${q.correctAnswer}`);
        }
    }
    
    console.log('\n=== VERIFICATION COMPLETE ===');
    process.exit(0);
}

verifyComplete().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
