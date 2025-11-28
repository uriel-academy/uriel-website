const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function checkFrenchQuestions() {
    console.log('Checking French questions in database...\n');
    
    // Check for french (lowercase)
    const frenchLower = await db.collection('questions')
        .where('subject', '==', 'french')
        .get();
    
    // Check for French (capitalized)
    const frenchCap = await db.collection('questions')
        .where('subject', '==', 'French')
        .get();
    
    console.log(`French questions (lowercase 'french'): ${frenchLower.size}`);
    console.log(`French questions (capitalized 'French'): ${frenchCap.size}`);
    
    const snapshot = frenchLower.size > 0 ? frenchLower : frenchCap;
    
    if (snapshot.size > 0) {
        // Analyze structure
        const byYear = {};
        const byType = {};
        
        snapshot.forEach(doc => {
            const data = doc.data();
            const year = data.year || 'unknown';
            const type = data.type || 'unknown';
            
            if (!byYear[year]) byYear[year] = 0;
            if (!byType[type]) byType[type] = 0;
            
            byYear[year]++;
            byType[type]++;
        });
        
        console.log('\n=== By Year ===');
        Object.keys(byYear).sort().forEach(year => {
            console.log(`  ${year}: ${byYear[year]} questions`);
        });
        
        console.log('\n=== By Type ===');
        Object.keys(byType).forEach(type => {
            console.log(`  ${type}: ${byType[type]} questions`);
        });
        
        // Show sample question
        const sampleDoc = snapshot.docs[0];
        const sampleData = sampleDoc.data();
        console.log('\n=== Sample Question ===');
        console.log(JSON.stringify(sampleData, null, 2));
    } else {
        console.log('\n❌ No French questions found in database');
        console.log('\nChecking English structure for reference...');
        
        const englishSnapshot = await db.collection('questions')
            .where('subject', '==', 'english')
            .limit(1)
            .get();
        
        if (!englishSnapshot.empty) {
            const englishData = englishSnapshot.docs[0].data();
            console.log('\n=== English Question Structure (Reference) ===');
            console.log(JSON.stringify(englishData, null, 2));
        }
    }
    
    process.exit(0);
}

checkFrenchQuestions().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
