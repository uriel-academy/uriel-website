const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function checkScienceQuestions() {
    console.log('Checking Integrated Science questions for existing images...\n');
    
    // Years with images based on DOCX extraction
    const yearsWithImages = ['2002', '2003', '2004', '2005', '2009', '2010', '2022'];
    
    for (const year of yearsWithImages) {
        console.log(`\n=== Year ${year} ===`);
        
        const snapshot = await db.collection('questions')
            .where('subject', '==', 'Integrated Science')
            .where('year', '==', year)
            .where('type', '==', 'multipleChoice')
            .orderBy('questionNumber')
            .get();
        
        console.log(`Total MCQ questions: ${snapshot.size}`);
        
        // Check if any have images
        const questionsWithImages = [];
        const questionsWithoutImages = [];
        
        snapshot.forEach(doc => {
            const data = doc.data();
            if (data.hasImage || data.imageUrl || data.imageUrls) {
                questionsWithImages.push({
                    id: doc.id,
                    questionNumber: data.questionNumber,
                    imageUrl: data.imageUrl,
                    imageUrls: data.imageUrls
                });
            } else {
                questionsWithoutImages.push({
                    id: doc.id,
                    questionNumber: data.questionNumber,
                    questionText: data.question ? data.question.substring(0, 100) : 'N/A'
                });
            }
        });
        
        console.log(`Questions with images: ${questionsWithImages.length}`);
        console.log(`Questions without images: ${questionsWithoutImages.length}`);
        
        if (questionsWithImages.length > 0) {
            console.log('\nQuestions with existing images:');
            questionsWithImages.forEach(q => {
                console.log(`  Q${q.questionNumber}: ${q.imageUrl || q.imageUrls}`);
            });
        }
        
        // Show first 5 questions for context
        if (questionsWithoutImages.length > 0) {
            console.log('\nSample questions (first 5):');
            questionsWithoutImages.slice(0, 5).forEach(q => {
                console.log(`  Q${q.questionNumber}: ${q.questionText}...`);
            });
        }
    }
    
    process.exit(0);
}

checkScienceQuestions().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
