const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK with service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  });
}

const db = admin.firestore();

async function importCareerTechnologyQuestions() {
  try {
    console.log('🚀 Starting Career Technology questions import...');

    const questionsPath = path.join(__dirname, 'assets', 'bece_json', 'bece_career_technology_questions.json');

    if (!fs.existsSync(questionsPath)) {
      throw new Error('Career Technology questions file not found');
    }

    const questionsData = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
    const currentDate = new Date().toISOString();

    console.log(`📊 Processing ${questionsData.length} Career Technology questions`);

    let importedCount = 0;
    const batch = db.batch();

    for (const question of questionsData) {
      const docId = `career_technology_${question.year}_q${question.questionNumber}`;
      const docRef = db.collection('questions').doc(docId);

      const questionDoc = {
        id: docId,
        questionText: question.questionText,
        type: 'multipleChoice',
        subject: 'careerTechnology',
        examType: 'bece',
        year: question.year,
        section: 'A',
        questionNumber: question.questionNumber,
        options: question.options,
        correctAnswer: question.correctAnswer || null,
        explanation: `This is question ${question.questionNumber} from the ${question.year} BECE Career Technology exam.`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Career Technology', 'BECE', question.year],
        createdAt: currentDate,
        updatedAt: currentDate,
        createdBy: 'system_import',
        isActive: true,
        metadata: {
          source: `BECE ${question.year}`,
          importDate: currentDate,
          verified: true
        }
      };

      batch.set(docRef, questionDoc);
      importedCount++;

      // Commit batch every 500 documents (Firestore limit is 500)
      if (importedCount % 500 === 0) {
        await batch.commit();
        console.log(`✅ Committed batch at ${importedCount} questions`);
      }
    }

    // Commit remaining questions
    if (importedCount % 500 !== 0) {
      await batch.commit();
    }

    console.log(`🎉 Successfully imported ${importedCount} Career Technology questions!`);

  } catch (error) {
    console.error('❌ Error importing Career Technology questions:', error);
  }
}

importCareerTechnologyQuestions();