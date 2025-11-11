const fs = require('fs');

/**
 * Complete parser for BECE English questions
 * Handles comprehension passages and all sections A-E
 */

const SECTION_INSTRUCTIONS = {
  'COMPREHENSION': 'Read the following passages carefully and answer the questions that follow.',
  'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
  'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
  'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
  'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
  'E': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
};

function parseEnglishQuestions(rawText, year) {
  // Pre-process
  rawText = rawText.replace(/SECTION\s*([A-E])/gi, '\n\nSECTION $1\n');
  rawText = rawText.replace(/COMPREHENSION/gi, '\n\nCOMPREHENSION\n');
  rawText = rawText.replace(/PASSAGE\s+(I+|[IV]+)/gi, '\n\nPASSAGE $1\n');
  rawText = rawText.replace(/LEXIS AND STRUCTURE/gi, '\n\nLEXIS AND STRUCTURE\n');
  
  // Split inline question numbers more aggressively
  // Handle "word.1." "word?1." "word!1." and "word'1."
  rawText = rawText.replace(/([.?!'"])\s*(\d+\.)/g, '$1\n\n$2\n');
  rawText = rawText.replace(/([a-z])(\d+\.)/gi, '$1\n\n$2\n');
  
  // Split options: "A.  textB.  textC.  textD.  textE.  text"
  rawText = rawText.replace(/([A-E])\.\s{2}/g, '\n$1.  ');
  
  const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const questions = [];
  const passages = [];
  let currentSection = 'COMPREHENSION';
  let currentPassage = null;
  let collectingPassage = false;
  let passageLines = [];
  let currentQuestion = null;
  let currentOptions = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Detect section changes
    if (/^(COMPREHENSION|SECTION\s+[A-E])$/i.test(line)) {
      if (/^SECTION\s+([A-E])$/i.test(line)) {
        const match = line.match(/^SECTION\s+([A-E])$/i);
        currentSection = match[1].toUpperCase();
      } else if (/^COMPREHENSION$/i.test(line)) {
        currentSection = 'COMPREHENSION';
      }
      collectingPassage = false;
      continue;
    }
    
    // Detect passage start
    if (/^PASSAGE\s+(I+|[IV]+)$/i.test(line)) {
      // Save previous passage if exists
      if (passageLines.length > 0) {
        passages.push({
          id: `english_${year}_passage_${passages.length + 1}`,
          content: passageLines.join(' ').trim(),
          title: currentPassage || `Passage ${passages.length + 1}`,
          subject: 'english',
          examType: 'bece',
          year: year.toString(),
          section: 'COMPREHENSION',
          questionRange: '', // Will be filled after all questions are parsed
          createdBy: 'admin',
          isActive: true
        });
      }
      currentPassage = line;
      passageLines = [];
      collectingPassage = true;
      continue;
    }
    
    // Skip instruction lines
    if (/^(Read the following|From the alternatives|Choose from|In each of|From the list)/i.test(line)) {
      collectingPassage = false;
      continue;
    }
    
    // Detect question number
    if (/^\d+\.$/.test(line)) {
      // Save previous question
      if (currentQuestion && currentOptions.length >= 4) {
        currentQuestion.options = currentOptions.slice(0, currentSection === 'COMPREHENSION' ? 5 : 4);
        questions.push(currentQuestion);
      }
      
      collectingPassage = false;
      const questionNumber = parseInt(line);
      currentQuestion = {
        id: `english_${year}_q${questionNumber}`,
        questionText: '',
        type: 'multipleChoice',
        subject: 'english',
        examType: 'bece',
        year: year,
        section: currentSection === 'COMPREHENSION' ? 'COMP' : currentSection,
        sectionInstructions: SECTION_INSTRUCTIONS[currentSection] || '',
        questionNumber: questionNumber,
        options: [],
        correctAnswer: '',
        marks: 1,
        difficulty: 'medium',
        topics: currentSection === 'COMPREHENSION' ? ['Comprehension'] : ['Grammar'],
        createdBy: 'admin',
        isActive: true
      };
      
      // Link to passage if in comprehension section
      if (currentSection === 'COMPREHENSION' && passages.length > 0) {
        currentQuestion.passageId = passages[passages.length - 1].id;
      }
      
      currentOptions = [];
      continue;
    }
    
    // Detect option (A-E)
    if (/^([A-E])\.\s+(.+)/.test(line) && currentQuestion) {
      const match = line.match(/^([A-E])\.\s+(.+)/);
      currentOptions.push(`${match[1]}. ${match[2]}`);
      continue;
    }
    
    // Handle option letter on one line, text on next (2011 format)
    if (/^([A-E])\.$/.test(line) && currentQuestion) {
      // Next line should be the option text
      if (i + 1 < lines.length && !/^([A-E]|SECTION|COMPREHENSION|PASSAGE|\d+)\.$/.test(lines[i + 1])) {
        i++;
        currentOptions.push(`${line} ${lines[i]}`);
      }
      continue;
    }
    
    // Collect passage content
    if (collectingPassage && line.length > 20) {
      passageLines.push(line);
      continue;
    }
    
    // Collect question text
    if (currentQuestion && !currentQuestion.questionText) {
      currentQuestion.questionText = line;
    } else if (currentQuestion && line.length > 10 && currentOptions.length === 0) {
      currentQuestion.questionText += ' ' + line;
    }
  }
  
  // Save last question
  if (currentQuestion && currentOptions.length >= 4) {
    currentQuestion.options = currentOptions.slice(0, currentSection === 'COMPREHENSION' ? 5 : 4);
    questions.push(currentQuestion);
  }
  
  // Save last passage
  if (passageLines.length > 0) {
    passages.push({
      id: `english_${year}_passage_${passages.length + 1}`,
      content: passageLines.join(' ').trim(),
      title: currentPassage || `Passage ${passages.length + 1}`,
      subject: 'english',
      examType: 'bece',
      year: year.toString(),
      section: 'COMPREHENSION',
      questionRange: '', // Will be filled after all questions are parsed
      createdBy: 'admin',
      isActive: true
    });
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
  console.log(`  - Questions with 4+ options: ${questions.filter(q => q.options && q.options.length >= 4).length}`);
  
  return jsonData;
}

// Main execution
const years = process.argv.slice(2);

if (years.length === 0) {
  console.log('📚 Complete English Questions Parser');
  console.log('═══════════════════════════════════════\n');
  console.log('Usage: node parse_english_complete.js [years...]');
  console.log('\nExamples:');
  console.log('  node parse_english_complete.js 1990');
  console.log('  node parse_english_complete.js 1990 1995 2000');
  console.log('  node parse_english_complete.js all');
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

console.log('📚 Complete English Questions Parser');
console.log('═══════════════════════════════════════\n');
console.log(`Processing ${yearsToProcess.length} years...\n`);

let processed = 0;
let failed = 0;
let totalQuestions = 0;
let totalPassages = 0;

yearsToProcess.forEach(year => {
  try {
    const result = processYear(year);
    if (result && result.questions.length > 0) {
      processed++;
      totalQuestions += result.questions.length;
      totalPassages += result.passages.length;
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

console.log('\n═══════════════════════════════════════');
console.log('✅ Processing Complete!');
console.log(`   Successfully processed: ${processed} years`);
console.log(`   Total questions: ${totalQuestions}`);
console.log(`   Total passages: ${totalPassages}`);
console.log(`   Failed/Empty: ${failed} years`);
