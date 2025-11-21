const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');

// Initialize Firebase Admin
const serviceAccount = require('../../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://uriel-academy-41fb0.firebaseio.com'
  });
}

const db = admin.firestore();

async function extractCreativeArtsAnswers() {
  try {
    console.log('📖 Extracting Creative Arts answers from Word document...');

    const answersPath = path.join(__dirname, '../../assets/bece Creative Art and Design/bece  Creative Art and Design 2024-2025  answers.docx');

    // Extract text from the answers document
    const result = await mammoth.extractRawText({ path: answersPath });
    const text = result.value;

    console.log('📄 Raw text extracted from answers document');

    // Parse the answers - looking for patterns like "1. A", "2. B", etc.
    const answerPattern = /(\d+)\.\s*([A-D])/gi;
    const answers = {};
    let match;

    while ((match = answerPattern.exec(text)) !== null) {
      const questionNumber = parseInt(match[1]);
      const answer = match[2];
      answers[questionNumber] = answer;
    }

    console.log(`📊 Found ${Object.keys(answers).length} answers in document`);

    // Sample some answers to verify
    console.log('\n🔍 Sample answers:');
    Object.keys(answers).slice(0, 10).forEach(qNum => {
      console.log(`   Q${qNum}: ${answers[qNum]}`);
    });

    // Update questions in database with correct answers
    console.log('\n🔄 Updating questions with correct answers...');

    const questionsRef = db.collection('questions');
    const creativeArtsQuery = await questionsRef
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    let updated = 0;
    let notFound = 0;

    for (const doc of creativeArtsQuery.docs) {
      const questionData = doc.data();
      const questionNumber = questionData.questionNumber;
      const correctAnswer = answers[questionNumber];

      if (correctAnswer) {
        // Map the letter answer to the full option text
        const options = questionData.options;
        let fullAnswer = '';

        if (options && options.length >= 4) {
          const index = correctAnswer.charCodeAt(0) - 'A'.charCodeAt(0);
          if (index >= 0 && index < options.length) {
            fullAnswer = options[index];
          }
        }

        if (fullAnswer) {
          await doc.ref.update({
            correctAnswer: fullAnswer
          });
          updated++;
          console.log(`✅ Updated Q${questionNumber}: ${correctAnswer} -> "${fullAnswer}"`);
        } else {
          console.log(`❌ Could not map answer for Q${questionNumber}: ${correctAnswer}`);
        }
      } else {
        notFound++;
        console.log(`⚠️  No answer found for Q${questionNumber}`);
      }
    }

    console.log(`\n🎉 Update completed!`);
    console.log(`✅ Questions updated: ${updated}`);
    console.log(`⚠️  Answers not found: ${notFound}`);

    // Verify the updates
    console.log('\n🔍 Verifying updates...');
    const verificationQuery = await questionsRef
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .limit(5)
      .get();

    verificationQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   Q${data.questionNumber}: "${data.correctAnswer || 'NOT SET'}"`);
    });

  } catch (error) {
    console.error('❌ Failed to extract answers:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the extraction
extractCreativeArtsAnswers();