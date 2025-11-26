const admin = require('firebase-admin');
const fs = require('fs');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function restoreOriginalEnglish() {
  console.log('Loading original JSON data...');
  const originalData = JSON.parse(fs.readFileSync('bece_theory_english.json', 'utf8'));
  
  console.log('Fetching current English theory questions...');
  const snapshot = await db.collection('questions')
    .where('type', '==', 'essay')
    .where('subject', '==', 'english')
    .get();

  console.log(`Found ${snapshot.docs.length} English theory questions\n`);
  
  // Group by year
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
    
    // Get original questions for this year
    const originalQuestions = originalData.filter(q => q.year === parseInt(year));
    
    if (originalQuestions.length === 0) {
      console.log(`  ⚠️  No original data found for ${year}`);
      continue;
    }
    
    // Determine format based on year: 1990-2009 = old format (composition only)
    const yearNum = parseInt(year);
    const isOldFormat = yearNum >= 1990 && yearNum <= 2009;
    
    console.log(`  Format: ${isOldFormat ? 'COMPOSITION ONLY (1990-2009)' : '3 PARTS (2010+)'}`);
    
    // Process each question
    for (const { doc, data } of questions) {
      const qNum = data.questionNumber;
      
      // Find the original question
      const original = originalQuestions.find(q => q.questionNumber === qNum);
      if (!original) {
        console.log(`  ⚠️  No original found for Q${qNum} (${year})`);
        continue;
      }
      
      // Use original clean text
      let cleanQuestionText = original.questionText;
      let partHeader = '';
      let paperInstructions = '';
      
      if (isOldFormat) {
        // Old format (1990-2009): All questions are composition
        partHeader = 'COMPOSITION';
        
        // Add simple paper instructions to Q1 only
        if (qNum === 1) {
          paperInstructions = 'THEORY QUESTIONS\nPAPER 2\n\n1 hour\n\nAnswer ONE question only from this section.\nYour composition should be about 250 words long.';
        }
      } else {
        // New format (2010+): Extract paper instructions from Q1 if present
        if (qNum === 1) {
          // Check if Q1 contains paper instructions (before the actual question)
          const lines = cleanQuestionText.split('\n');
          
          // Look for patterns that indicate paper instructions
          const hasInstructions = cleanQuestionText.includes('This paper consists of three parts') ||
                                  cleanQuestionText.includes('Answer three questions in all');
          
          if (hasInstructions) {
            // Find where the actual question starts (usually after instructions)
            let actualQuestionStartIndex = -1;
            for (let i = 0; i < lines.length; i++) {
              const line = lines[i].trim();
              // Question typically starts with "A new curriculum", "Write", etc. or a number
              if (line.length > 20 && !line.includes('This paper') && !line.includes('Answer') && 
                  !line.includes('Credit will be given') && !line.includes('answer booklet')) {
                actualQuestionStartIndex = i;
                break;
              }
            }
            
            if (actualQuestionStartIndex > 0) {
              paperInstructions = lines.slice(0, actualQuestionStartIndex).join('\n').trim();
              cleanQuestionText = lines.slice(actualQuestionStartIndex).join('\n').trim();
            }
          }
        }
        
        // Assign parts based on question number
        if (qNum <= 3) {
          partHeader = 'PART A - WRITING';
        } else if (qNum === 4) {
          partHeader = 'PART B - READING';
        } else if (qNum === 5) {
          partHeader = 'PART C - LITERATURE';
        }
      }
      
      // Update question with original clean text
      batch.update(doc.ref, {
        questionText: cleanQuestionText,
        partHeader: partHeader,
        paperInstructions: paperInstructions,
      });
      
      batchCount++;
      updateCount++;
      
      // Commit batch every 500 updates
      if (batchCount >= 500) {
        await batch.commit();
        console.log(`  Committed batch of ${batchCount} updates`);
        batch = db.batch();
        batchCount = 0;
      }
      
      console.log(`  Updated Q${qNum} (${year}) - ${partHeader}`);
    }
  }
  
  // Commit final batch
  if (batchCount > 0) {
    await batch.commit();
    console.log(`Committed final batch of ${batchCount} updates`);
  }

  console.log(`\n✅ Restored ${updateCount} English theory questions with original clean text`);
  process.exit(0);
}

restoreOriginalEnglish();
