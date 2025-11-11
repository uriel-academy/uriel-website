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

async function importEnglishQuestions() {
  try {
    console.log('🚀 Starting BECE English Questions Import...\n');
    
    // Read the JSON file
    const jsonPath = process.argv.find(arg => arg.startsWith('--file='))?.split('=')[1] 
      || './bece_english_sample.json';
    
    const jsonData = JSON.parse(fs.readFileSync(path.resolve(jsonPath), 'utf8'));
    
    console.log(`📖 Loaded data from: ${jsonPath}`);
    console.log(`   Passages: ${jsonData.passages?.length || 0}`);
    console.log(`   Questions: ${jsonData.questions?.length || 0}\n`);
    
    // Import passages first
    if (jsonData.passages && jsonData.passages.length > 0) {
      console.log('📚 Importing passages...');
      const passageBatch = db.batch();
      let passageCount = 0;
      
      for (const passage of jsonData.passages) {
        const passageRef = db.collection('passages').doc(passage.id);
        const passageData = {
          id: passage.id,
          title: passage.title,
          content: passage.content,
          subject: passage.subject,
          examType: passage.examType,
          year: passage.year,
          section: passage.section,
          questionRange: passage.questionRange,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: passage.createdBy || 'admin',
          isActive: passage.isActive !== false
        };
        
        passageBatch.set(passageRef, passageData);
        passageCount++;
        
        if (passageCount % 10 === 0) {
          console.log(`   ✓ Prepared ${passageCount} passages...`);
        }
      }
      
      await passageBatch.commit();
      console.log(`✅ Imported ${passageCount} passages successfully!\n`);
    }
    
    // Import questions
    if (jsonData.questions && jsonData.questions.length > 0) {
      console.log('❓ Importing questions...');
      const questionBatch = db.batch();
      let questionCount = 0;
      let withPassage = 0;
      let withInstructions = 0;
      
      for (const question of jsonData.questions) {
        const questionRef = db.collection('questions').doc(question.id);
        const questionData = {
          id: question.id,
          questionText: question.questionText,
          type: question.type,
          subject: question.subject,
          examType: question.examType,
          year: question.year,
          section: question.section,
          questionNumber: question.questionNumber,
          options: question.options || null,
          correctAnswer: question.correctAnswer,
          explanation: question.explanation || null,
          imageUrl: question.imageUrl || null,
          marks: question.marks || 1,
          difficulty: question.difficulty || 'medium',
          topics: question.topics || [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: question.createdBy || 'admin',
          isActive: question.isActive !== false,
        };
        
        // Add optional passage/instruction fields
        if (question.passageId) {
          questionData.passageId = question.passageId;
          withPassage++;
        }
        
        if (question.sectionInstructions) {
          questionData.sectionInstructions = question.sectionInstructions;
          withInstructions++;
        }
        
        if (question.relatedQuestions) {
          questionData.relatedQuestions = question.relatedQuestions;
        }
        
        questionBatch.set(questionRef, questionData);
        questionCount++;
        
        if (questionCount % 50 === 0) {
          console.log(`   ✓ Prepared ${questionCount} questions...`);
        }
      }
      
      await questionBatch.commit();
      console.log(`✅ Imported ${questionCount} questions successfully!`);
      console.log(`   📚 Questions with passages: ${withPassage}`);
      console.log(`   📋 Questions with instructions: ${withInstructions}\n`);
    }
    
    // Summary
    console.log('═══════════════════════════════════════════');
    console.log('✅ Import completed successfully!');
    console.log(`   Total passages: ${jsonData.passages?.length || 0}`);
    console.log(`   Total questions: ${jsonData.questions?.length || 0}`);
    console.log('═══════════════════════════════════════════\n');
    
  } catch (error) {
    console.error('❌ Error importing English questions:', error);
    process.exit(1);
  }
}

// Run the import
importEnglishQuestions()
  .then(() => {
    console.log('🎉 Import script completed!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  });
