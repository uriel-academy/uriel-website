const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');

// Get all mathematics docx files
const mathDir = './assets/Mathematics';
const files = fs.readdirSync(mathDir)
  .filter(f => f.includes('questions') && f.endsWith('.docx'))
  .sort();

console.log(`Found ${files.length} mathematics files to process\n`);

async function extractMathQuestions() {
  const outputDir = './assets/mathematics_json';
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  for (const file of files) {
    // Extract year from filename
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) {
      console.log(`⚠️  Skipping ${file} - no year found`);
      continue;
    }
    const year = yearMatch[1];

    console.log(`📄 Processing ${file} (${year})...`);

    const filePath = path.join(mathDir, file);
    
    try {
      // Extract text and images
      const result = await mammoth.extractRawText({ path: filePath });
      const text = result.value;
      
      // Parse questions
      const questions = parseQuestions(text, year);
      
      if (questions.length === 0) {
        console.log(`   ⚠️  No questions found in ${file}`);
        continue;
      }

      // Create JSON structure
      const jsonData = {
        year: year,
        subject: 'mathematics',
        multiple_choice: {}
      };

      questions.forEach((q, idx) => {
        const qNum = q.questionNumber || (idx + 1);
        jsonData.multiple_choice[`q${qNum}`] = {
          question: q.question,
          possibleAnswers: q.options,
          correctAnswer: q.correctAnswer || 'A' // Default if not found
        };

        if (q.explanation) {
          jsonData.multiple_choice[`q${qNum}`].explanation = q.explanation;
        }
      });

      // Save JSON
      const outputFile = path.join(outputDir, `bece_mathematics_${year}.json`);
      fs.writeFileSync(outputFile, JSON.stringify(jsonData, null, 2));
      
      console.log(`   ✅ Extracted ${questions.length} questions → ${outputFile}`);
      
    } catch (error) {
      console.error(`   ❌ Error processing ${file}:`, error.message);
    }
  }

  console.log('\n✨ Extraction complete!');
  console.log(`📂 JSON files saved to: ${outputDir}`);
}

function parseQuestions(text, year) {
  const questions = [];
  
  // Split by question numbers (e.g., "1.", "2.", etc.)
  // This is a simple pattern - may need adjustment based on actual format
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);
  
  let currentQuestion = null;
  let currentSection = 'question';
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Detect new question (starts with number followed by period or parenthesis)
    const questionMatch = line.match(/^(\d+)[\.\)]\s*(.*)/);
    if (questionMatch) {
      // Save previous question
      if (currentQuestion && currentQuestion.question) {
        questions.push(currentQuestion);
      }
      
      // Start new question
      currentQuestion = {
        questionNumber: parseInt(questionMatch[1]),
        question: questionMatch[2].trim(),
        options: {},
        correctAnswer: null,
        explanation: null
      };
      currentSection = 'question';
      continue;
    }
    
    // Detect options (A., B., C., D. or A), B), C), D))
    const optionMatch = line.match(/^([A-D])[\.\)]\s*(.*)/);
    if (optionMatch && currentQuestion) {
      currentQuestion.options[optionMatch[1]] = optionMatch[2].trim();
      continue;
    }
    
    // Append to current question text if not an option
    if (currentQuestion && currentSection === 'question' && !optionMatch && line.length > 3) {
      currentQuestion.question += ' ' + line;
    }
  }
  
  // Add last question
  if (currentQuestion && currentQuestion.question) {
    questions.push(currentQuestion);
  }
  
  return questions;
}

// Run extraction
extractMathQuestions()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
