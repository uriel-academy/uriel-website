const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const mathDir = './assets/Mathematics';

// Create directory for extracted images
const imagesDir = './assets/mathematics_images';
if (!fs.existsSync(imagesDir)) {
  fs.mkdirSync(imagesDir, { recursive: true });
}

const files = fs.readdirSync(mathDir)
  .filter(f => f.includes('questions') && f.endsWith('.docx'))
  .sort();

console.log(`Found ${files.length} mathematics files to re-process\n`);

async function reimportMathematics() {
  let totalImported = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let imagesExtracted = 0;

  for (const file of files) {
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) continue;
    
    const year = yearMatch[1];
    console.log(`📄 Processing ${file} (${year})...`);

    const filePath = path.join(mathDir, file);
    
    try {
      // Extract with HTML to get images
      const htmlResult = await mammoth.convertToHtml({ 
        path: filePath,
        convertImage: mammoth.images.imgElement(function(image) {
          return image.read("base64").then(function(imageBuffer) {
            imagesExtracted++;
            const extension = image.contentType.split('/')[1] || 'png';
            const filename = `math_${year}_img_${imagesExtracted}.${extension}`;
            const imagePath = path.join(imagesDir, filename);
            
            // Save base64 image to file
            fs.writeFileSync(imagePath, imageBuffer, 'base64');
            
            // Return relative path for use in questions
            return { src: `assets/mathematics_images/${filename}` };
          });
        })
      });

      // Also get plain text for parsing
      const textResult = await mammoth.extractRawText({ path: filePath });
      const text = textResult.value;
      
      const questions = parseQuestionsImproved(text, year);
      
      if (questions.length === 0) {
        console.log(`   ⚠️  No questions found`);
        continue;
      }

      // Import/update questions
      for (const q of questions) {
        // Check if question exists
        const existingQuery = await db.collection('questions')
          .where('year', '==', year)
          .where('subject', '==', 'mathematics')
          .where('questionNumber', '==', q.questionNumber)
          .limit(1)
          .get();

        const questionData = {
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
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_import_v2',
          isActive: true
        };

        if (!existingQuery.empty) {
          // Update existing
          await existingQuery.docs[0].ref.update(questionData);
          totalUpdated++;
        } else {
          // Create new
          questionData.createdAt = admin.firestore.FieldValue.serverTimestamp();
          await db.collection('questions').add(questionData);
          totalImported++;
        }
      }
      
      console.log(`   ✅ Processed ${questions.length} questions from ${year}`);
      
    } catch (error) {
      console.error(`   ❌ Error processing ${file}:`, error.message);
    }
  }

  console.log(`\n📊 Import Summary:`);
  console.log(`   ✅ New: ${totalImported}`);
  console.log(`   🔄 Updated: ${totalUpdated}`);
  console.log(`   ⏭️  Skipped: ${totalSkipped}`);
  console.log(`   🖼️  Images: ${imagesExtracted}`);
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
      i++;
      
      // Collect question text - everything until we hit an option marker (A., B., etc.)
      let questionText = '';
      while (i < lines.length) {
        // Check if we've hit an option
        if (lines[i].match(/^[A-E]\.$/)) {
          break;
        }
        // Add non-empty lines to question text
        if (lines[i]) {
          questionText += (questionText ? ' ' : '') + lines[i];
        }
        i++;
      }
      
      // Now collect options (A through E)
      const options = {};
      const optionsArray = [];
      
      while (i < lines.length) {
        const optionMatch = lines[i].match(/^([A-E])\.$/);
        if (optionMatch) {
          const optionLetter = optionMatch[1];
          i++;
          
          // Collect option text until next option or question number
          let optionText = '';
          while (i < lines.length) {
            // Stop if we hit another option or question number
            if (lines[i].match(/^[A-E]\.$/)) {
              break;
            }
            if (lines[i].match(/^\d+\.$/)) {
              break;
            }
            // Add non-empty lines to option text
            if (lines[i]) {
              optionText += (optionText ? ' ' : '') + lines[i];
            }
            i++;
          }
          
          optionText = optionText.trim();
          if (optionText) {
            options[optionLetter] = optionText;
            optionsArray.push(`${optionLetter}. ${optionText}`);
          }
          
          // If we hit next question number, break out of options loop
          if (i < lines.length && lines[i].match(/^\d+\.$/)) {
            break;
          }
        } else {
          break;
        }
      }
      
      // Only add question if it has text and at least 2 options
      if (questionText.trim() && Object.keys(options).length >= 2) {
        questions.push({
          questionNumber,
          question: questionText.trim(),
          options,
          optionsArray,
          correctAnswer: 'A', // Default
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
reimportMathematics()
  .then(() => {
    console.log('\n✨ Re-import complete!');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
