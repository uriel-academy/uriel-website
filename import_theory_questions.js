const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importTheoryQuestions() {
  console.log('🚀 Starting theory questions import...\n');

  try {
    let importedCount = 0;
    const currentTime = Date.now();
    const currentDate = new Date().toISOString();
    
    // Subject files to import
    const subjectFiles = [
      'bece_theory_asante_twi.json',
      'bece_theory_career_technology.json',
      'bece_theory_creative_arts.json',
      'bece_theory_english.json',
      'bece_theory_french.json',
      'bece_theory_ga.json',
      'bece_theory_ict.json',
      'bece_theory_mathematics.json',
      'bece_theory_rme.json',
      'bece_theory_integrated_science.json',
      'bece_theory_social_studies.json'
    ];
    
    for (const filename of subjectFiles) {
      try {
        const filePath = path.join(__dirname, filename);
        
        // Skip if file doesn't exist
        if (!fs.existsSync(filePath)) {
          console.log(`⚠️  Skipping ${filename} - file not found`);
          continue;
        }
        
        const questionsData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        console.log(`📚 Processing ${questionsData.length} theory questions from ${filename}`);
        
        // Import each question
        let batch = db.batch();
        let batchCount = 0;
        
        for (const question of questionsData) {
          const questionDoc = {
            id: question.id,
            questionText: question.questionText,
            questionNumber: question.questionNumber,
            marks: question.marks || 5,
            type: 'theory',
            subject: question.subject.toLowerCase().replace(/\s+/g, '_'),
            subjectDisplay: question.subject,
            examType: 'bece',
            year: question.year,
            difficulty: question.difficulty || 'medium',
            topics: question.topics || [],
            createdAt: currentDate,
            updatedAt: currentDate,
            createdBy: 'system_import',
            isActive: true,
            metadata: {
              source: `BECE ${question.year}`,
              importDate: currentDate,
              verified: true,
              timestamp: currentTime
            }
          };
          
          const docRef = db.collection('theoryQuestions').doc(question.id);
          batch.set(docRef, questionDoc);
          batchCount++;
          importedCount++;
          
          // Commit batch every 500 documents (Firestore limit)
          if (batchCount >= 500) {
            await batch.commit();
            console.log(`   ✅ Committed batch of ${batchCount} questions`);
            batch = db.batch();
            batchCount = 0;
          }
        }
        
        // Commit remaining questions
        if (batchCount > 0) {
          await batch.commit();
          console.log(`   ✅ Committed final batch of ${batchCount} questions`);
        }
        
        console.log(`✅ Completed ${filename}: imported ${questionsData.length} questions\n`);
        
      } catch (fileError) {
        console.error(`❌ Error processing ${filename}:`, fileError.message);
      }
    }
    
    console.log('='.repeat(50));
    console.log(`✨ Import completed successfully!`);
    console.log('='.repeat(50));
    console.log(`📊 Total questions imported: ${importedCount}`);
    console.log(`📚 Subjects processed: ${subjectFiles.length}`);
    
    // Update metadata
    try {
      await db.collection('app_metadata').doc('content').set({
        theoryQuestionsImported: true,
        theoryQuestionsCount: importedCount,
        lastTheoryImportTimestamp: currentTime,
        lastUpdated: currentDate
      }, { merge: true });
      console.log('✅ Updated content metadata\n');
    } catch (error) {
      console.error('⚠️  Error updating metadata:', error.message);
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Fatal error importing theory questions:', error);
    process.exit(1);
  }
}

// Run the import
importTheoryQuestions();
