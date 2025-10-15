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

async function importTriviaQuestions() {
  const triviaDir = path.join(__dirname, 'assets', 'trivia');
  const files = fs.readdirSync(triviaDir);

  console.log(`Found ${files.length} trivia files to process...`);

  // Load trivia_index.json to get proper category names
  const indexPath = path.join(triviaDir, 'trivia_index.json');
  const indexData = JSON.parse(fs.readFileSync(indexPath, 'utf8'));
  const categoryMapping = {};

  // Create mapping from filename to display name
  for (const category of indexData.summary) {
    const questionsFile = category.questions_file;
    const displayName = category.subject;
    categoryMapping[questionsFile] = displayName;
  }

  console.log('📋 Category mapping:', categoryMapping);

  let totalImported = 0;
  let categoriesProcessed = 0;

  // Get all question files (ending with _questions.json)
  const questionFiles = files.filter(file => file.endsWith('_questions.json'));

  for (const questionFile of questionFiles) {
    try {
      // Use display name from mapping instead of filename
      const categoryName = categoryMapping[questionFile];
      if (!categoryName) {
        console.log(`   ⚠️ Skipping ${questionFile} - not found in trivia_index.json`);
        continue;
      }

      const answerFile = questionFile.replace('_questions.json', '_answers.json');

      console.log(`\n📚 Processing category: ${categoryName}`);

      // Read questions file
      const questionsPath = path.join(triviaDir, questionFile);
      const questionsData = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));

      // Read answers file
      const answersPath = path.join(triviaDir, answerFile);
      const answersData = JSON.parse(fs.readFileSync(answersPath, 'utf8'));

      // Extract questions
      const questions = [];
      const questionKeys = Object.keys(questionsData).filter(key => key.startsWith('q'));

      for (const key of questionKeys) {
        const qData = questionsData[key];
        const correctAnswer = answersData[key];

        if (!qData || !correctAnswer) {
          console.log(`   ⚠️ Skipping ${key} - missing data`);
          continue;
        }

        // Find the index of the correct answer
        const correctLetter = correctAnswer.trim().charAt(0).toUpperCase(); // Extract just the letter (A, B, C, D)
        const correctIndex = qData.possibleAnswers.findIndex(answer => {
          const optionLetter = answer.trim().charAt(0).toUpperCase();
          return optionLetter === correctLetter;
        });

        if (correctIndex === -1) {
          console.log(`   ⚠️ Skipping ${key} - correct answer not found in options`);
          continue;
        }

        // Convert to Question format
        const question = {
          id: `${categoryName.toLowerCase().replace(/\s+/g, '_')}_${key}`,
          questionText: qData.question,
          type: 'trivia',
          subject: 'trivia',
          examType: 'trivia',
          year: '2024', // Default year for trivia
          section: categoryName, // Use category as section
          questionNumber: parseInt(key.replace('q', '')),
          options: qData.possibleAnswers,
          correctAnswer: qData.possibleAnswers[correctIndex], // Store the actual answer text
          explanation: '', // No explanations in trivia data
          marks: 1,
          difficulty: 'medium',
          topics: [categoryName],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system',
          isActive: true,
          triviaCategory: categoryName, // Store the display name
          correctAnswerIndex: correctIndex, // Keep this for backward compatibility if needed
        };

        questions.push(question);
      }

      console.log(`   📝 Found ${questions.length} questions for ${categoryName}`);

      // Import questions in batches
      const batchSize = 500;
      for (let i = 0; i < questions.length; i += batchSize) {
        const batch = db.batch();
        const batchQuestions = questions.slice(i, i + batchSize);

        for (const question of batchQuestions) {
          const docRef = db.collection('questions').doc(question.id);
          batch.set(docRef, question);
        }

        await batch.commit();
        console.log(`   ✅ Imported batch ${Math.floor(i / batchSize) + 1} (${batchQuestions.length} questions)`);
      }

      totalImported += questions.length;
      categoriesProcessed++;

    } catch (error) {
      console.error(`❌ Error processing ${questionFile}:`, error.message);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`📊 Import Summary:`);
  console.log(`   📚 Categories processed: ${categoriesProcessed}`);
  console.log(`   ❓ Total questions imported: ${totalImported}`);
  console.log('='.repeat(60));
}

// Run the import
importTriviaQuestions()
  .then(() => {
    console.log('\n✨ All trivia questions imported successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });