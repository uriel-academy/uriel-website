const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();

// Load BECE 2014 questions and answers
const questionsPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', 'bece_2014_questions.json');
const answersPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', 'bece_2014_answers.json');

const questionsData = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
const answersData = JSON.parse(fs.readFileSync(answersPath, 'utf8'));

console.log('📚 Starting BECE 2014 RME Questions Import...\n');
console.log(`Year: ${questionsData.year}`);
console.log(`Subject: ${questionsData.subject}`);
console.log(`Variant: ${questionsData.variant}\n`);

async function importQuestions() {
  try {
    let importedCount = 0;
    const batch = db.batch();
    
    // Import multiple choice questions
    const mcQuestions = questionsData.multiple_choice;
    const mcAnswers = answersData.multiple_choice;
    
    for (const [key, questionData] of Object.entries(mcQuestions)) {
      const questionNumber = key.replace('q', '');
      const correctAnswer = mcAnswers[key];
      
      // Find the correct answer option (A, B, C, D)
      const correctOption = correctAnswer.charAt(0); // Get 'A', 'B', 'C', or 'D'
      
      const questionDoc = {
        question: questionData.question,
        options: questionData.possibleAnswers,
        correctAnswer: correctOption,
        correctAnswerText: correctAnswer,
        subject: 'RME',
        examType: 'BECE',
        year: 2014,
        variant: questionsData.variant || 'N/A',
        questionNumber: parseInt(questionNumber),
        difficulty: 'medium',
        topic: 'Religious And Moral Education',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      const docRef = db.collection('questions').doc();
      batch.set(docRef, questionDoc);
      importedCount++;
      
      if (importedCount % 10 === 0) {
        console.log(`✓ Prepared ${importedCount} questions...`);
      }
    }
    
    // Commit the batch
    await batch.commit();
    console.log(`\n✅ Successfully imported ${importedCount} BECE 2014 RME questions to Firebase!`);
    console.log(`📊 Total questions in database: ${importedCount}`);
    
    // Verify import
    const snapshot = await db.collection('questions')
      .where('examType', '==', 'BECE')
      .where('year', '==', 2014)
      .where('subject', '==', 'RME')
      .get();
    
    console.log(`\n🔍 Verification: Found ${snapshot.size} questions for BECE 2014 RME in database`);
    
    // Show sample questions
    console.log('\n📝 Sample imported questions:');
    snapshot.docs.slice(0, 3).forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. Question ${data.questionNumber}: ${data.question.substring(0, 80)}...`);
      console.log(`   Correct Answer: ${data.correctAnswer} - ${data.correctAnswerText}`);
    });
    
  } catch (error) {
    console.error('❌ Error importing questions:', error);
    throw error;
  }
}

async function main() {
  try {
    // Check if questions already exist
    const existingQuestions = await db.collection('questions')
      .where('examType', '==', 'BECE')
      .where('year', '==', 2014)
      .where('subject', '==', 'RME')
      .get();
    
    if (existingQuestions.size > 0) {
      console.log(`⚠️  Found ${existingQuestions.size} existing BECE 2014 RME questions.`);
      console.log('Do you want to delete them and re-import? (This script will overwrite)\n');
      
      // Delete existing questions
      console.log('🗑️  Deleting existing questions...');
      const deleteBatch = db.batch();
      existingQuestions.docs.forEach(doc => {
        deleteBatch.delete(doc.ref);
      });
      await deleteBatch.commit();
      console.log(`✓ Deleted ${existingQuestions.size} existing questions\n`);
    }
    
    // Import questions
    await importQuestions();
    
    console.log('\n🎉 Import completed successfully!');
    console.log('\n📱 The questions are now live and available in:');
    console.log('   ✓ Quiz Taker');
    console.log('   ✓ Past Questions Section');
    console.log('   ✓ Question Collections');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Import failed:', error);
    process.exit(1);
  }
}

// Run the import
main();
