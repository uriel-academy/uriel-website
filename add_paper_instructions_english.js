const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Generate proper paper instructions for English theory questions
function getPaperInstructions(year) {
  return `THEORY QUESTIONS
PAPER 2

1 hour

This paper consists of three parts: A, B and C.

Answer three questions in all; one question from Part A and all the questions in Part B and Part C.

Answer all questions in your answer booklet.

Credit will be given for clarity of expression and orderly presentation of material.`;
}

function getPartAInstructions() {
  return `PART A - WRITING
[30 marks]

Answer one question only from this part.
Your composition should be about 250 words long.`;
}

function getPartBInstructions() {
  return `PART B - READING
[20 marks]

Read the following passage carefully and answer all the questions which follow.`;
}

function getPartCInstructions() {
  return `PART C - LITERATURE
[10 marks]

Answer all the questions in this part.`;
}

async function updateEnglishQuestions() {
  try {
    console.log('Fetching English theory questions...');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .get();
    
    console.log(`Found ${snapshot.size} English theory questions`);
    
    // Group questions by year
    const questionsByYear = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const year = data.year;
      if (!questionsByYear[year]) {
        questionsByYear[year] = [];
      }
      questionsByYear[year].push({ doc, data });
    });
    
    let batch = db.batch();
    let batchCount = 0;
    let updateCount = 0;
    
    for (const [year, questions] of Object.entries(questionsByYear)) {
      console.log(`\nProcessing ${year} - ${questions.length} questions`);
      
      // Sort by question number
      questions.sort((a, b) => a.data.questionNumber - b.data.questionNumber);
      
      const paperInstructions = getPaperInstructions(year);
      
      for (const { doc, data } of questions) {
        const qNum = data.questionNumber;
        let fullQuestionText = '';
        let partHeader = '';
        
        // Determine which part this question belongs to
        // Usually Q1-3 are Part A (Writing), Q4 is Part B (Reading/Comprehension), Q5 is Part C (Literature)
        if (qNum <= 3) {
          // Part A - Writing
          if (qNum === 1) {
            fullQuestionText = `${paperInstructions}\n\n${getPartAInstructions()}\n\n${qNum}. ${data.questionText}`;
          } else {
            fullQuestionText = `${qNum}. ${data.questionText}`;
          }
          partHeader = 'PART A - WRITING';
        } else if (qNum === 4) {
          // Part B - Reading/Comprehension
          fullQuestionText = `${getPartBInstructions()}\n\n${data.questionText}`;
          partHeader = 'PART B - READING';
        } else if (qNum === 5) {
          // Part C - Literature
          fullQuestionText = `${getPartCInstructions()}\n\n${data.questionText}`;
          partHeader = 'PART C - LITERATURE';
        } else {
          fullQuestionText = data.questionText;
          partHeader = '';
        }
        
        batch.update(doc.ref, {
          questionText: fullQuestionText,
          partHeader: partHeader,
          paperInstructions: qNum === 1 ? paperInstructions : '',
        });
        
        batchCount++;
        updateCount++;
        
        console.log(`  Updated Q${qNum} (${year})`);
        
        // Commit batch every 500 operations
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`  Committed batch of ${batchCount} updates`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
    
    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${batchCount} updates`);
    }
    
    console.log(`\n✅ Updated ${updateCount} English theory questions with paper instructions`);
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

updateEnglishQuestions();
