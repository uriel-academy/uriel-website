const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Get all mathematics docx files
const mathDir = './assets/Mathematics';
const files = fs.readdirSync(mathDir)
  .filter(f => f.includes('questions') && f.endsWith('.docx'))
  .sort();

console.log(`Found ${files.length} mathematics files to process\n`);

async function importMathematics() {
  let totalImported = 0;
  let totalSkipped = 0;

  for (const file of files) { // Import all years
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) {
      console.log(`⚠️  Skipping ${file} - no year found`);
      continue;
    }
    const year = yearMatch[1];

    console.log(`📄 Processing ${file} (${year})...`);

    const filePath = path.join(mathDir, file);
    
    try {
      const result = await mammoth.extractRawText({ path: filePath });
      const text = result.value;
      
      const questions = parseQuestionsImproved(text, year);
      
      if (questions.length === 0) {
        console.log(`   ⚠️  No questions found in ${file}`);
        continue;
      }

      // Import to Firestore
      for (const q of questions) {
        // Check if question already exists
        const existingQuery = await db.collection('questions')
          .where('year', '==', year)
          .where('subject', '==', 'mathematics')
          .where('questionNumber', '==', q.questionNumber)
          .limit(1)
          .get();

        if (!existingQuery.empty) {
          console.log(`   ⏭️  Q${q.questionNumber}: Already exists, skipping`);
          totalSkipped++;
          continue;
        }

        // Add to Firestore
        await db.collection('questions').add({
          year,
          subject: 'mathematics',
          examType: 'bece',
          questionNumber: q.questionNumber,
          questionText: q.question,
          options: q.optionsArray,
          correctAnswer: q.correctAnswer || 'A',
          explanation: q.explanation || '',
          imageUrl: null,
          imageBeforeQuestion: null,
          imageAfterQuestion: null,
          optionImages: null,
          type: 'multipleChoice',
          section: 'A',
          marks: 1,
          difficulty: 'medium',
          topics: ['Mathematics', 'BECE', year],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_import',
          isActive: true
        });

        totalImported++;
      }
      
      console.log(`   ✅ Imported ${questions.length} questions from ${year}`);
      
    } catch (error) {
      console.error(`   ❌ Error processing ${file}:`, error.message);
    }
  }

  console.log(`\n📊 Import Summary:`);
  console.log(`   ✅ Imported: ${totalImported}`);
  console.log(`   ⏭️  Skipped: ${totalSkipped}`);
  console.log(`   📝 Total: ${totalImported + totalSkipped}`);
}

function parseQuestionsImproved(text, year) {
  const questions = [];
  const lines = text.split('\n').map(l => l.trim());
  
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    
    // Check if this line is a question number (just a number followed by period)
    const questionMatch = line.match(/^(\d+)\.$/);
    if (questionMatch) {
      const questionNumber = parseInt(questionMatch[1]);
      
      // Skip empty lines and collect question text
      i++;
      while (i < lines.length && lines[i] === '') i++;
      
      let questionText = '';
      // Collect all text until we hit an option (A., B., etc.)
      while (i < lines.length && !lines[i].match(/^[A-D]\.$/)) {
        if (lines[i]) {
          questionText += (questionText ? ' ' : '') + lines[i];
        }
        i++;
      }
      
      // Now collect options
      const options = {};
      const optionsArray = [];
      while (i < lines.length) {
        const optionMatch = lines[i].match(/^([A-E])\.$/);
        if (optionMatch) {
          const optionLetter = optionMatch[1];
          i++;
          
          // Skip empty lines
          while (i < lines.length && lines[i] === '') i++;
          
          let optionText = '';
          // Collect option text until next option or question number
          while (i < lines.length && !lines[i].match(/^[A-E]\.$/) && !lines[i].match(/^\d+\.$/)) {
            if (lines[i]) {
              optionText += (optionText ? ' ' : '') + lines[i];
            }
            i++;
          }
          
          options[optionLetter] = optionText.trim();
          optionsArray.push(`${optionLetter}. ${optionText.trim()}`);
          
          // If we hit next question number, break
          if (i < lines.length && lines[i].match(/^\d+\.$/)) {
            break;
          }
        } else {
          break;
        }
      }
      
      if (questionText && Object.keys(options).length > 0) {
        questions.push({
          questionNumber,
          question: questionText.trim(),
          options,
          optionsArray,
          correctAnswer: 'A', // Default - will need manual correction or answer key
          explanation: ''
        });
      }
      
      continue;
    }
    
    i++;
  }
  
  return questions;
}

// Run import
importMathematics()
  .then(() => {
    console.log('\n✨ Import complete!');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
