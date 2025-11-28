const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function verifyScienceImages() {
    console.log('Verifying Integrated Science images...\n');
    
    // Get all integratedScience questions with images
    const snapshot = await db.collection('questions')
        .where('subject', '==', 'integratedScience')
        .where('hasImage', '==', true)
        .get();
    
    console.log(`Total integratedScience questions with images: ${snapshot.size}\n`);
    
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
            imageCount: data.imageUrls ? data.imageUrls.length : 1,
            imageUrls: data.imageUrls || [data.imageUrl]
        });
    });
    
    // Display by year
    for (const year of Object.keys(byYear).sort()) {
        const questions = byYear[year];
        const totalImages = questions.reduce((sum, q) => sum + q.imageCount, 0);
        
        console.log(`=== Year ${year} ===`);
        console.log(`Questions with images: ${questions.length}`);
        console.log(`Total images: ${totalImages}`);
        
        questions.forEach(q => {
            console.log(`  Q${q.questionNumber}: ${q.imageCount} image(s)`);
            if (q.imageCount > 1) {
                q.imageUrls.forEach((url, idx) => {
                    const filename = url.split('/').pop();
                    console.log(`    ${idx + 1}. ${filename}`);
                });
            }
        });
        console.log();
    }
    
    // Overall stats
    const totalQuestions = snapshot.size;
    const totalImages = Object.values(byYear).reduce((sum, questions) => {
        return sum + questions.reduce((s, q) => s + q.imageCount, 0);
    }, 0);
    
    console.log('=== SUMMARY ===');
    console.log(`Questions with images: ${totalQuestions}`);
    console.log(`Total images: ${totalImages}`);
    console.log(`Years covered: ${Object.keys(byYear).join(', ')}`);
    
    // Sample image URLs
    console.log('\nSample image URLs:');
    const sampleQuestion = snapshot.docs[0].data();
    if (sampleQuestion.imageUrls) {
        sampleQuestion.imageUrls.forEach(url => {
            console.log(`  ${url}`);
        });
    } else if (sampleQuestion.imageUrl) {
        console.log(`  ${sampleQuestion.imageUrl}`);
    }
    
    process.exit(0);
}

verifyScienceImages().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
