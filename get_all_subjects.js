const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function getAllSubjects() {
    console.log('Fetching all subjects in database...\n');
    
    const snapshot = await db.collection('questions')
        .where('type', '==', 'multipleChoice')
        .get();
    
    console.log(`Total MCQ questions: ${snapshot.size}`);
    
    // Group by subject
    const bySubject = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        const subject = data.subject || 'unknown';
        if (!bySubject[subject]) {
            bySubject[subject] = {
                count: 0,
                withImages: 0,
                years: new Set()
            };
        }
        bySubject[subject].count++;
        if (data.hasImage || data.imageUrl) {
            bySubject[subject].withImages++;
        }
        if (data.year) {
            bySubject[subject].years.add(data.year);
        }
    });
    
    // Display results
    console.log('\n=== Subjects in Database ===');
    const subjects = Object.keys(bySubject).sort();
    
    for (const subject of subjects) {
        const info = bySubject[subject];
        const years = Array.from(info.years).sort();
        const yearRange = years.length > 0 ? `${years[0]}-${years[years.length - 1]}` : 'N/A';
        
        console.log(`\n${subject}:`);
        console.log(`  Total questions: ${info.count}`);
        console.log(`  With images: ${info.withImages} (${((info.withImages/info.count)*100).toFixed(1)}%)`);
        console.log(`  Year range: ${yearRange}`);
        console.log(`  Years: ${years.join(', ')}`);
    }
    
    process.exit(0);
}

getAllSubjects().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
