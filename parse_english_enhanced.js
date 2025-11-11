const fs = require('fs');
const path = require('path');

/**
 * Enhanced parser for BECE English questions
 * Handles concatenated text from DOCX extraction
 */

const SECTION_INSTRUCTIONS = {
  'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
  'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
  'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
  'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
  'E': 'Read the passage carefully and answer the questions that follow.',
  'F': 'Choose the option that best completes each sentence.',
};

function parseEnglishQuestions(rawText, year) {
  // Pre-process: Clean up concatenated text
  rawText = rawText.replace(/SECTION\s*([A-Z])/gi, '\n\nSECTION $1\n');
  rawText = rawText.replace(/PART\s+(I+|[IV]+)/gi, '\n\nPART $1\n');
  
  // Split options that are concatenated: "A.  textB.  textC.  textD.  text"
  rawText = rawText.replace(/([A-D])\.\s{2}/g, '\n$1.  ');
  
  const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const questions = [];
  let currentSection = 'A';
  let currentQuestion = null;
  let currentOptions = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Skip section instructions and headers
    if (/^(PART|SECTION|From the alternatives|Choose from|In each of)/i.test(line)) {
      if (/^SECTION\s+([A-Z])$/i.test(line)) {
        const match = line.match(/^SECTION\s+([A-Z])$/i);
        currentSection = match[1].toUpperCase();
      }
      continue;
    }
    
    // Detect question number (standalone number with period)
    if (/^\d+\.$/.test(line)) {
      // Save previous question
      if (currentQuestion && currentOptions.length === 4) {
        currentQuestion.options = currentOptions;
        questions.push(currentQuestion);
      }
      
      const questionNumber = parseInt(line);
      currentQuestion = {
        id: `english_${year}_q${questionNumber}`,
        questionText: '',
        type: 'multipleChoice',
        subject: 'english',
        examType: 'bece',
        year: year,
        section: currentSection,
        sectionInstructions: SECTION_INSTRUCTIONS[currentSection] || '',
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
    
    // Detect option (A., B., C., D. followed by text)
    if (/^([A-D])\.\s+(.+)/.test(line) && currentQuestion) {
      const match = line.match(/^([A-D])\.\s+(.+)/);
      currentOptions.push(`${match[1]}. ${match[2]}`);
      continue;
    }
    
    // Otherwise, it's part of the question text
    if (currentQuestion && !currentQuestion.questionText) {
      currentQuestion.questionText = line;
    } else if (currentQuestion && line.length > 10) {
      // Append to question text
      currentQuestion.questionText += ' ' + line;
    }
  }
  
  // Save last question
  if (currentQuestion && currentOptions.length === 4) {
    currentQuestion.options = currentOptions;
    questions.push(currentQuestion);
  }
  
  return { passages: [], questions };
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
  console.log(`  - Questions with 4 options: ${questions.filter(q => q.options && q.options.length === 4).length}`);
  
  return jsonData;
}

// Main execution
const years = process.argv.slice(2);

if (years.length === 0) {
  console.log('📚 Enhanced English Questions JSON Generator');
  console.log('════════════════════════════════════════════\n');
  console.log('Usage: node parse_english_enhanced.js [years...]');
  console.log('\nExamples:');
  console.log('  node parse_english_enhanced.js 2018');
  console.log('  node parse_english_enhanced.js 1990 1995 2000');
  console.log('  node parse_english_enhanced.js all');
  process.exit(0);
}

let yearsToProcess = [];

if (years[0] === 'all') {
  for (let y = 1990; y <= 2025; y++) {
    if (y !== 2021) yearsToProcess.push(y.toString());
  }
} else {
  yearsToProcess = years;
}

console.log('📚 Enhanced English Questions JSON Generator');
console.log('════════════════════════════════════════════\n');
console.log(`Processing ${yearsToProcess.length} years...\n`);

let processed = 0;
let failed = 0;
let totalQuestions = 0;

yearsToProcess.forEach(year => {
  try {
    const result = processYear(year);
    if (result && result.questions.length > 0) {
      processed++;
      totalQuestions += result.questions.length;
    } else if (result) {
      console.log(`   ⚠️  No questions extracted for ${year}`);
      failed++;
    } else {
      failed++;
    }
  } catch (error) {
    console.error(`❌ Error processing ${year}:`, error.message);
    failed++;
  }
});

console.log('\n════════════════════════════════════════════');
console.log('✅ Processing Complete!');
console.log(`   Successfully processed: ${processed} years`);
console.log(`   Total questions: ${totalQuestions}`);
console.log(`   Failed/Empty: ${failed} years`);
