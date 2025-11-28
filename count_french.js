const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function countFrench() {
    const snapshot = await db.collection('bece_mcq')
        .where('subject', '==', 'french')
        .get();
    
    const byYear = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        if (!byYear[data.year]) byYear[data.year] = 0;
        byYear[data.year]++;
    });
    
    console.log('French MCQ by year:');
    Object.keys(byYear).sort().forEach(year => {
        console.log(`  ${year}: ${byYear[year]} questions`);
    });
    
    console.log('\nTotal:', snapshot.size);
    
    process.exit(0);
}

countFrench();
