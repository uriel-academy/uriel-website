const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin if not already done
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// RME Questions Data (1999 BECE) - Sample first 5 questions
const rmeQuestionsData = {
  "year": 1999,
  "subject": "Religious And Moral Education - RME",
  "q1": {
    "question": "According to Christian teaching, God created man and woman on the",
    "possibleAnswers": [
      "A. 1st day",
      "B. 2nd day", 
      "C. 3rd day",
      "D. 5th day",
      "E. 6th day"
    ]
  },
  "q2": {
    "question": "Palm Sunday is observed by Christians to remember the",
    "possibleAnswers": [
      "A. birth and baptism of Christ",
      "B. resurrection and appearance of Christ",
      "C. joyful journey of Christ into Jerusalem",
      "D. baptism of the Holy Spirit",
      "E. last supper and sacrifice of Christ"
    ]
  },
  "q3": {
    "question": "God gave Noah and his people the rainbow to remember",
    "possibleAnswers": [
      "A. the floods which destroyed the world",
      "B. the disobedience of the idol worshippers",
      "C. that God would not destroy the world with water again",
      "D. the building of the ark",
      "E. the usefulness of the heavenly bodies"
    ]
  },
  "q4": {
    "question": "All the religions in Ghana believe in",
    "possibleAnswers": [
      "A. Jesus Christ",
      "B. the Bible",
      "C. the Prophet Muhammed",
      "D. the Rain god",
      "E. the Supreme God"
    ]
  },
  "q5": {
    "question": "The Muslim prayers observed between Asr and Isha is",
    "possibleAnswers": [
      "A. Zuhr",
      "B. Jumu'ah",
      "C. Idd",
      "D. Subhi",
      "E. Maghrib"
    ]
  }
};

// Correct answers
const correctAnswers = {
  "q1": "E",
  "q2": "C",
  "q3": "C",
  "q4": "E",
  "q5": "E"
};

exports.importRMEQuestions = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Starting RME questions import...');
    
    const batch = db.batch();
    let importedCount = 0;
    
    // Import each question
    for (let i = 1; i <= 5; i++) { // Import first 5 as test
      const questionKey = `q${i}`;
      const questionData = rmeQuestionsData[questionKey];
      const correctAnswer = correctAnswers[questionKey];
      
      if (!questionData || !correctAnswer) {
        console.warn(`Missing data for question ${i}`);
        continue;
      }
      
      const questionDoc = {
        id: `rme_1999_q${i}`,
        questionText: questionData.question,
        type: 'multipleChoice',
        subject: 'religiousMoralEducation',
        examType: 'bece',
        year: '1999',
        section: 'A',
        questionNumber: i,
        options: questionData.possibleAnswers,
        correctAnswer: correctAnswer,
        explanation: `This is question ${i} from the 1999 BECE RME exam.`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Religious And Moral Education', 'BECE', '1999'],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system_import',
        isActive: true,
        metadata: {
          source: 'BECE 1999',
          importDate: admin.firestore.FieldValue.serverTimestamp(),
          verified: true
        }
      };
      
      const docRef = db.collection('questions').doc(questionDoc.id);
      batch.set(docRef, questionDoc);
      importedCount++;
      
      console.log(`Prepared question ${i}: ${questionData.question.substring(0, 50)}...`);
    }
    
    // Commit the batch
    await batch.commit();
    console.log(`Successfully imported ${importedCount} RME questions to Firestore!`);
    
    // Update metadata
    await db.collection('app_metadata').doc('content').set({
      availableYears: admin.firestore.FieldValue.arrayUnion('1999'),
      availableSubjects: admin.firestore.FieldValue.arrayUnion('Religious And Moral Education - RME'),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      rmeQuestionsImported: true,
      rmeQuestionsCount: importedCount
    }, { merge: true });
    
    console.log('Updated content metadata');
    
    res.status(200).json({
      success: true,
      message: `Successfully imported ${importedCount} RME questions!`,
      questionsImported: importedCount
    });
    
  } catch (error) {
    console.error('Error importing RME questions:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});