const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Generate proper paper instructions for English theory questions
function getPaperInstructions(year, numQuestions) {
  if (numQuestions <= 4) {
    // Old format (1990-2009): Only composition questions
    return `BECE ENGLISH LANGUAGE
PAPER 2 - ESSAY WRITING

1 hour

Answer ONE question only.

Your composition should be about 250 words long.

Credit will be given for clarity of expression and orderly presentation of material.`;
  } else {
    // New format (2010+): Three parts
    return `THEORY QUESTIONS
PAPER 2

1 hour

This paper consists of three parts: A, B and C.

Answer three questions in all; one question from Part A and all the questions in Part B and Part C.

Answer all questions in your answer booklet.

Credit will be given for clarity of expression and orderly presentation of material.`;
  }
}

function getPartAInstructions(isOldFormat) {
  if (isOldFormat) {
    return `Answer ONE question only from this section.
Your composition should be about 250 words long.`;
  }
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
      
      // Check Q1 to determine format based on instructions in the text
      const q1Text = questions[0].data.questionText || '';
      const hasThreeParts = q1Text.includes('three parts: A, B and C') || q1Text.includes('PART A') || questions.length >= 5;
      const isCompositionOnly = questions.length <= 4 && !hasThreeParts;
      
      console.log(`  Format: ${hasThreeParts ? '3 PARTS' : 'COMPOSITION ONLY'}`);
      
      // Don't regenerate paper instructions - they're already in the text
      // Just update the partHeader field
      
      for (const { doc, data } of questions) {
        const qNum = data.questionNumber;
        let partHeader = '';
        
        if (isCompositionOnly) {
          // Old format (1990-2016 with 4 questions): All are composition questions
          partHeader = 'COMPOSITION';
        } else {
          // New format (2017+): Three parts
          if (qNum <= 3) {
            partHeader = 'PART A - WRITING';
          } else if (qNum === 4) {
            partHeader = 'PART B - READING';
          } else if (qNum === 5) {
            partHeader = 'PART C - LITERATURE';
          } else {
            partHeader = 'PART A - WRITING'; // Default for extra questions
          }
        }
        
        // Only update partHeader, keep existing questionText and paperInstructions
        batch.update(doc.ref, {
          partHeader: partHeader,
        });
        
        batchCount++;
        updateCount++;
        
        console.log(`  Updated Q${qNum} (${year}) - ${partHeader}`);
        
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
    
    console.log(`\n✅ Updated ${updateCount} English theory questions with proper format for each year`);
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

updateEnglishQuestions();
