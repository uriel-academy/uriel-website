const fs = require('fs');
const path = require('path');

/**
 * Process extracted raw text and create properly formatted JSON
 * This script parses the raw text more intelligently to extract options
 */

function parseEnglishQuestions(rawText, year) {
  const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const questions = [];
  const passages = [];
  
  let currentQuestion = null;
  let currentOptions = [];
  let questionNumber = 0;
  let passageContent = '';
  let inPassage = false;
  let passageCount = 0;
  let currentSection = 'A';
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Detect section changes
    if (/SECTION\s+([ABC])/i.test(line)) {
      const match = line.match(/SECTION\s+([ABC])/i);
      currentSection = match[1];
      continue;
    }
    
    // Check if this is a question number (standalone number followed by a period)
    if (/^\d+\.$/.test(line)) {
      // Save previous question if exists
      if (currentQuestion && currentOptions.length > 0) {
        currentQuestion.options = currentOptions;
        questions.push(currentQuestion);
      }
      
      questionNumber = parseInt(line);
      currentQuestion = {
        id: `english_${year}_q${questionNumber}`,
        questionText: '',
        type: 'multipleChoice',
        subject: 'english',
        examType: 'bece',
        year: year,
        section: currentSection,
        questionNumber: questionNumber,
        options: [],
        correctAnswer: '',
        marks: 1,
        difficulty: 'medium',
        topics: ['Grammar'],
        createdBy: 'admin',
        isActive: true
      };
      currentOptions = [];
      continue;
    }
    
    // Check if this is an option (A., B., C., D.)
    if (/^([ABCD])\.\s*$/.test(line)) {
      const optionLetter = line.match(/^([ABCD])\./)[1];
      // Next line should be the option text
      if (i + 1 < lines.length) {
        i++;
        const optionText = lines[i];
        currentOptions.push(`${optionLetter}. ${optionText}`);
      }
      continue;
    }
    
    // If we have a current question and this isn't an option marker, it's part of the question text
    if (currentQuestion && !currentQuestion.questionText) {
      currentQuestion.questionText = line;
    } else if (currentQuestion && currentQuestion.questionText && !currentOptions.length) {
      // Still building question text
      currentQuestion.questionText += ' ' + line;
    }
  }
  
  // Save last question
  if (currentQuestion && currentOptions.length > 0) {
    currentQuestion.options = currentOptions;
    questions.push(currentQuestion);
  }
  
  return { passages, questions };
}

function processYear(year) {
  const rawPath = `./extracted_english/english_${year}_raw.txt`;
  
  if (!fs.existsSync(rawPath)) {
    console.log(`⚠️  Skipping ${year} - raw file not found`);
    return null;
  }
  
  console.log(`\n📝 Processing ${year}...`);
  
  const rawText = fs.readFileSync(rawPath, 'utf8');
  const { passages, questions } = parseEnglishQuestions(rawText, year);
  
  const jsonData = {
    passages: passages,
    questions: questions
  };
  
  const outputPath = `./english_${year}_questions.json`;
  fs.writeFileSync(outputPath, JSON.stringify(jsonData, null, 2), 'utf8');
  
  console.log(`✓ Created ${outputPath}`);
  console.log(`  - ${passages.length} passages`);
  console.log(`  - ${questions.length} questions`);
  console.log(`  - Questions with options: ${questions.filter(q => q.options && q.options.length === 4).length}`);
  
  return jsonData;
}

// Process specific years or all
const years = process.argv.slice(2);

if (years.length === 0) {
  console.log('📚 English Questions JSON Generator');
  console.log('════════════════════════════════════\n');
  console.log('Usage: node parse_english_to_json.js [years...]');
  console.log('\nExamples:');
  console.log('  node parse_english_to_json.js 2022');
  console.log('  node parse_english_to_json.js 2022 2023 2024');
  console.log('  node parse_english_to_json.js all');
  console.log('\n💡 Start with one year to review the output format');
  process.exit(0);
}

let yearsToProcess = [];

if (years[0] === 'all') {
  // Process all years from 1990-2025
  for (let y = 1990; y <= 2025; y++) {
    if (y !== 2021) yearsToProcess.push(y.toString());  // Skip 2021 if missing
  }
} else {
  yearsToProcess = years;
}

console.log('📚 English Questions JSON Generator');
console.log('════════════════════════════════════\n');
console.log(`Processing ${yearsToProcess.length} years...\n`);

let processed = 0;
let failed = 0;

yearsToProcess.forEach(year => {
  try {
    const result = processYear(year);
    if (result) {
      processed++;
    } else {
      failed++;
    }
  } catch (error) {
    console.error(`❌ Error processing ${year}:`, error.message);
    failed++;
  }
});

console.log('\n════════════════════════════════════');
console.log('✅ Processing Complete!');
console.log(`   Successfully processed: ${processed} years`);
console.log(`   Failed: ${failed} years`);
console.log('\n⚠️  NEXT STEPS:');
console.log('   1. Review the generated JSON files');
console.log('   2. Add correct answers from the answer key PDF');
console.log('   3. Run import: node import_bece_english.js --file=./english_2022_questions.json');
