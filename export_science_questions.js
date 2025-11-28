const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function exportScienceQuestions() {
    console.log('Exporting Integrated Science questions for years with images...\n');
    
    const yearsWithImages = {
        '2002': 3, // 3 images
        '2003': 1, // 1 image
        '2004': 2, // 2 images
        '2005': 5, // 5 images
        '2009': 2, // 2 images
        '2010': 5, // 5 images
        '2022': 1  // 1 image
    };
    
    const allQuestions = {};
    
    for (const year of Object.keys(yearsWithImages)) {
        console.log(`Fetching ${year} questions...`);
        
        const snapshot = await db.collection('questions')
            .where('subject', '==', 'integratedScience')
            .where('year', '==', year)
            .where('type', '==', 'multipleChoice')
            .orderBy('questionNumber')
            .get();
        
        const questions = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            questions.push({
                id: doc.id,
                questionNumber: data.questionNumber,
                question: data.question,
                options: data.options,
                correctAnswer: data.correctAnswer
            });
        });
        
        allQuestions[year] = questions;
        console.log(`  Found ${questions.length} questions (expected ${yearsWithImages[year]} images)`);
    }
    
    // Save to file for manual review
    fs.writeFileSync(
        'science_questions_for_image_mapping.json',
        JSON.stringify(allQuestions, null, 2)
    );
    
    console.log('\n=== EXPORT COMPLETE ===');
    console.log('Questions exported to: science_questions_for_image_mapping.json');
    console.log('\nNext steps:');
    console.log('1. Review the exported questions');
    console.log('2. Review the extracted images in assets/science_images/');
    console.log('3. Create a mapping file: science_image_mapping.json');
    console.log('   Format: { "year": { "questionNumber": ["imageFile1.png", ...] } }');
    
    process.exit(0);
}

exportScienceQuestions().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
