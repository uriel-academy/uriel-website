const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function getCompleteImageSummary() {
    console.log('=== COMPLETE IMAGE SUMMARY FOR ALL SUBJECTS ===\n');
    
    // Get all MCQ questions
    const snapshot = await db.collection('questions')
        .where('type', '==', 'multipleChoice')
        .get();
    
    console.log(`Total MCQ questions in database: ${snapshot.size}\n`);
    
    // Group by subject
    const bySubject = {};
    snapshot.forEach(doc => {
        const data = doc.data();
        const subject = data.subject || 'unknown';
        
        if (!bySubject[subject]) {
            bySubject[subject] = {
                total: 0,
                withImages: 0,
                totalImages: 0
            };
        }
        
        bySubject[subject].total++;
        
        if (data.hasImage || data.imageUrl || data.imageUrls) {
            bySubject[subject].withImages++;
            
            // Count total images
            if (data.imageUrls && Array.isArray(data.imageUrls)) {
                bySubject[subject].totalImages += data.imageUrls.length;
            } else {
                bySubject[subject].totalImages += 1;
            }
        }
    });
    
    // Display results sorted by subject
    const subjects = Object.keys(bySubject).sort();
    
    let totalWithImages = 0;
    let totalImageCount = 0;
    
    for (const subject of subjects) {
        const info = bySubject[subject];
        const percentage = ((info.withImages / info.total) * 100).toFixed(1);
        const status = info.withImages > 0 ? '✓' : '✗';
        
        console.log(`${status} ${subject}:`);
        console.log(`   Total questions: ${info.total}`);
        console.log(`   Questions with images: ${info.withImages} (${percentage}%)`);
        console.log(`   Total images: ${info.totalImages}`);
        console.log();
        
        totalWithImages += info.withImages;
        totalImageCount += info.totalImages;
    }
    
    // Overall summary
    console.log('=== OVERALL SUMMARY ===');
    console.log(`Total MCQ questions: ${snapshot.size}`);
    console.log(`Questions with images: ${totalWithImages}`);
    console.log(`Total images: ${totalImageCount}`);
    console.log(`Percentage with images: ${((totalWithImages / snapshot.size) * 100).toFixed(1)}%`);
    
    // Breakdown by subject with images
    console.log('\n=== SUBJECTS WITH IMAGES ===');
    const subjectsWithImages = subjects.filter(s => bySubject[s].withImages > 0);
    
    if (subjectsWithImages.length > 0) {
        for (const subject of subjectsWithImages) {
            const info = bySubject[subject];
            console.log(`${subject}: ${info.withImages} questions, ${info.totalImages} images`);
        }
    } else {
        console.log('No subjects have images yet.');
    }
    
    process.exit(0);
}

getCompleteImageSummary().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
