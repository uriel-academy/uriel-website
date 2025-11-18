const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function updateCorrectAnswers() {
  console.log('Updating questions with correct answers...\n');
  
  // Load parsed answers
  const answersFile = 'mathematics_answers.json';
  if (!fs.existsSync(answersFile)) {
    console.error('Answers file not found! Run parse_mathematics_answers.js first.');
    process.exit(1);
  }
  
  const answers = JSON.parse(fs.readFileSync(answersFile, 'utf8'));
  
  let totalUpdated = 0;
  let notFound = 0;
  let errors = 0;
  
  // Process each year
  const years = Object.keys(answers).sort();
  
  for (const year of years) {
    console.log(`Processing ${year}...`);
    const yearAnswers = answers[year];
    let yearUpdated = 0;
    
    // Get all questions for this year
    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .where('year', '==', year)
      .get();
    
    if (questionsSnapshot.empty) {
      console.log(`  ⚠ No questions found for ${year}`);
      continue;
    }
    
    // Create batch updates (max 500 per batch)
    const batches = [];
    let currentBatch = db.batch();
    let batchCount = 0;
    
    questionsSnapshot.forEach(doc => {
      const questionData = doc.data();
      const questionNum = questionData.questionNumber;
      
      if (yearAnswers[questionNum]) {
        currentBatch.update(doc.ref, {
          correctAnswer: yearAnswers[questionNum],
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        batchCount++;
        yearUpdated++;
        
        // Start new batch if we hit 500
        if (batchCount === 500) {
          batches.push(currentBatch);
          currentBatch = db.batch();
          batchCount = 0;
        }
      } else {
        notFound++;
        console.log(`  ⚠ No answer found for Q${questionNum} (${year})`);
      }
    });
    
    // Add final batch if it has any updates
    if (batchCount > 0) {
      batches.push(currentBatch);
    }
    
    // Commit all batches
    for (let i = 0; i < batches.length; i++) {
      try {
        await batches[i].commit();
      } catch (error) {
        console.error(`  ❌ Error committing batch ${i + 1}:`, error.message);
        errors++;
      }
    }
    
    console.log(`  ✅ Updated ${yearUpdated} questions`);
    totalUpdated += yearUpdated;
  }
  
  console.log('\n' + '='.repeat(50));
  console.log(`Total questions updated: ${totalUpdated}`);
  console.log(`Answers not found: ${notFound}`);
  console.log(`Errors: ${errors}`);
  console.log('='.repeat(50));
}

updateCorrectAnswers()
  .then(() => {
    console.log('\n✅ Correct answers update completed!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n❌ Fatal error:', err);
    process.exit(1);
  });
