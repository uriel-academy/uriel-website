const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = process.argv.find(arg => arg.startsWith('--serviceAccount='))?.split('=')[1] 
  || './uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

const serviceAccount = require(path.resolve(serviceAccountPath));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importIntegratedScienceQuestions() {
  try {
    console.log('🚀 Starting BECE Integrated Science Questions Import...\n');
    
    const jsonPath = './assets/bece_json/bece_integrated_science_questions.json';
    const questionsData = JSON.parse(fs.readFileSync(path.resolve(jsonPath), 'utf8'));
    
    console.log(`📖 Loaded ${questionsData.length} questions from: ${jsonPath}\n`);
    
    // Count by year
    const byYear = {};
    questionsData.forEach(q => {
      byYear[q.year] = (byYear[q.year] || 0) + 1;
    });
    
    console.log('📊 Questions by year:');
    Object.keys(byYear).sort().forEach(y => {
      console.log(`   ${y}: ${byYear[y]} questions`);
    });
    console.log();
    
    // Import questions in batches (Firestore batch limit is 500)
    console.log('❓ Importing questions to Firestore...');
    const batchSize = 500;
    const batches = Math.ceil(questionsData.length / batchSize);
    
    let totalImported = 0;
    
    for (let i = 0; i < batches; i++) {
      const batch = db.batch();
      const start = i * batchSize;
      const end = Math.min(start + batchSize, questionsData.length);
      const currentBatch = questionsData.slice(start, end);
      
      for (const question of currentBatch) {
        const docId = `integrated_science_${question.year}_q${question.questionNumber}`;
        const questionRef = db.collection('questions').doc(docId);
        
        const questionDoc = {
          id: docId,
          questionText: question.questionText,
          type: 'multipleChoice',
          subject: 'integratedScience',
          examType: 'bece',
          year: question.year,
          section: 'A',
          questionNumber: question.questionNumber,
          options: question.options,
          correctAnswer: question.correctAnswer || null,
          explanation: `This is question ${question.questionNumber} from the ${question.year} BECE Integrated Science exam.`,
          marks: 1,
          difficulty: 'medium',
          topics: ['Integrated Science', 'BECE', question.year],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_import',
          isActive: true,
          metadata: {
            source: `BECE ${question.year}`,
            importDate: new Date().toISOString(),
            verified: true
          }
        };
        
        batch.set(questionRef, questionDoc);
      }
      
      await batch.commit();
      totalImported += currentBatch.length;
      console.log(`   ✓ Batch ${i + 1}/${batches}: Imported ${currentBatch.length} questions (Total: ${totalImported})`);
    }
    
    console.log(`\n✅ Successfully imported ${totalImported} Integrated Science questions!\n`);
    
    // Summary
    console.log('📊 Import Summary:');
    console.log(`   Total Questions: ${totalImported}`);
    console.log(`   Years Covered: ${Object.keys(byYear).length} (${Math.min(...Object.keys(byYear))} - ${Math.max(...Object.keys(byYear))})`);
    console.log(`   Subject: Integrated Science`);
    console.log(`   Exam Type: BECE`);
    console.log(`\n🎉 Import complete!`);
    
  } catch (error) {
    console.error('❌ Error importing Integrated Science questions:', error);
    process.exit(1);
  }
}

// Run the import
importIntegratedScienceQuestions()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
