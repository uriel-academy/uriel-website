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
    
    // Import multiple choice questions - using same format as import_all_bece_rme.js
    const mcQuestions = questionsData.multiple_choice;
    const mcAnswers = answersData.multiple_choice;
    
    for (const [key, questionData] of Object.entries(mcQuestions)) {
      const questionNumber = parseInt(key.replace('q', ''));
      const correctAnswer = mcAnswers[key];
      
      const docId = `rme_2014_q${questionNumber}`;
      
      const questionDoc = {
        id: docId,
        questionText: questionData.question,
        type: 'multipleChoice',
        subject: 'religiousMoralEducation',
        subjectName: 'Religious And Moral Education',
        subjectCode: 'RME',
        examType: 'bece',
        examName: 'Basic Education Certificate Examination',
        year: '2014',
        section: 'A',
        questionNumber: questionNumber,
        options: questionData.possibleAnswers || [],
        correctAnswer: correctAnswer,
        explanation: `BECE 2014 RME Question ${questionNumber}`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Religious And Moral Education', 'BECE', '2014'],
        tags: ['rme', 'bece', '2014', 'past-question'],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import_2024',
        isActive: true,
        isPremium: false,
        metadata: {
          source: 'BECE 2014 RME',
          importDate: new Date().toISOString(),
          verified: true,
          version: '2.0'
        }
      };
      
      const docRef = db.collection('questions').doc(docId);
      batch.set(docRef, questionDoc, { merge: false });
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
      .where('examType', '==', 'bece')
      .where('year', '==', '2014')
      .where('subjectCode', '==', 'RME')
      .get();
    
    console.log(`\n🔍 Verification: Found ${snapshot.size} questions for BECE 2014 RME in database`);
    
    // Show sample questions
    console.log('\n📝 Sample imported questions:');
    snapshot.docs.slice(0, 3).forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. Question ${data.questionNumber}: ${data.questionText.substring(0, 80)}...`);
      console.log(`   Correct Answer: ${data.correctAnswer}`);
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
      .where('examType', '==', 'bece')
      .where('year', '==', '2014')
      .where('subjectCode', '==', 'RME')
      .get();
    
    if (existingQuestions.size > 0) {
      console.log(`⚠️  Found ${existingQuestions.size} existing BECE 2014 RME questions.`);
      console.log('🗑️  Deleting existing questions to re-import with correct format...\n');
      
      // Delete existing questions
      const deleteBatch = db.batch();
      existingQuestions.docs.forEach(doc => {
        deleteBatch.delete(doc.ref);
      });
      await deleteBatch.commit();
      console.log(`✓ Deleted ${existingQuestions.size} existing questions\n`);
    }
    
    // Import questions
    await importQuestions();
    
    // Update metadata to include 2014
    console.log('\n📊 Updating metadata...');
    await db.collection('app_metadata').doc('content').set({
      availableYears: admin.firestore.FieldValue.arrayUnion('2014'),
      availableSubjects: admin.firestore.FieldValue.arrayUnion('Religious And Moral Education', 'RME'),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      rmeQuestionsImported: true,
      rmeYears: admin.firestore.FieldValue.arrayUnion('2014')
    }, { merge: true });
    console.log('✓ Metadata updated');
    
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
