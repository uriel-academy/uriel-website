const fs = require('fs');
const pdfParse = require('pdf-parse');

/**
 * Parse English questions from PDF files (2024-2025)
 */

const SECTION_INSTRUCTIONS = {
  'COMPREHENSION': 'Read the following passages carefully and answer the questions that follow.',
  'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
  'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
  'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
  'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
  'E': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
};

async function parseEnglishPDF(pdfPath, year) {
  console.log(`\n📄 Parsing ${year} from PDF...`);
  
  const dataBuffer = fs.readFileSync(pdfPath);
  const data = await pdfParse(dataBuffer);
  let rawText = data.text;
  
  // Pre-process
  rawText = rawText.replace(/PART\s+(I+|[IV]+)/gi, '');
  rawText = rawText.replace(/LEXIS AND STRUCTURE/gi, '');
  rawText = rawText.replace(/SECTION\s*([A-E])/gi, '\n\nSECTION $1\n');
  rawText = rawText.replace(/COMPREHENSION/gi, '\n\nCOMPREHENSION\n');
  rawText = rawText.replace(/PASSAGE\s+(I+|[IV]+)/gi, '\n\nPASSAGE $1\n');
  
  // Split question numbers
  rawText = rawText.replace(/([a-z])\.\s*(\d+)\.\s+/gi, '$1.\n\n$2.\n');
  rawText = rawText.replace(/([A-E])\.\s+/g, '\n$1.  ');
  
  const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const questions = [];
  const passages = [];
  let currentSection = 'A';
  let currentPassage = null;
  let currentPassageId = null;
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
    
    // Detect passage start (Section E in 2024-2025)
    if (/^PASSAGE\s+(I+|[IV]+)$/i.test(line) || (currentSection === 'E' && /^(UNIT\s+(I+|[1-2]))/i.test(line))) {
      // Save previous passage
      if (passageLines.length > 0) {
        const passageId = `english_${year}_passage_${passages.length + 1}`;
        passages.push({
          id: passageId,
          content: passageLines.join(' ').trim(),
          title: currentPassage || `Passage ${passages.length + 1}`,
          subject: 'english',
          examType: 'bece',
          year: year.toString(),
          section: currentSection,
          questionRange: '',
          createdBy: 'admin',
          isActive: true
        });
      }
      currentPassage = line;
      passageLines = [];
      collectingPassage = true;
      currentPassageId = `english_${year}_passage_${passages.length + 1}`;
      continue;
    }
    
    // Skip instruction lines
    if (/^(Read the following|From the alternatives|Choose from|In each of|From the list)/i.test(line)) {
      collectingPassage = false;
      continue;
    }
    
    // Collect passage lines
    if (collectingPassage) {
      passageLines.push(line);
      continue;
    }
    
    // Detect question number
    if (/^\d+\.$/.test(line)) {
      // Save previous question
      if (currentQuestion && currentOptions.length >= 4) {
        currentQuestion.options = currentOptions.slice(0, 4);
        questions.push(currentQuestion);
      }
      
      const questionNumber = parseInt(line.replace('.', ''));
      currentQuestion = {
        id: `english_${year}_q${questionNumber}`,
        questionNumber,
        questionText: '',
        options: [],
        correctAnswer: '',
        explanation: '',
        subject: 'english',
        examType: 'bece',
        year: year.toString(),
        section: currentSection,
        sectionInstructions: SECTION_INSTRUCTIONS[currentSection] || '',
        passageId: ((currentSection === 'COMPREHENSION' || currentSection === 'E') && currentPassageId) ? currentPassageId : null,
        createdBy: 'admin',
        isActive: true
      };
      currentOptions = [];
      continue;
    }
    
    // Detect options
    if (/^[A-D]\.\s+/.test(line) && currentQuestion) {
      const optionText = line.replace(/^[A-D]\.\s+/, '').trim();
      currentOptions.push(optionText);
      continue;
    }
    
    // Accumulate question text
    if (currentQuestion && currentOptions.length === 0 && line.length > 0) {
      currentQuestion.questionText += (currentQuestion.questionText ? ' ' : '') + line;
    }
  }
  
  // Save last question
  if (currentQuestion && currentOptions.length >= 4) {
    currentQuestion.options = currentOptions.slice(0, 4);
    questions.push(currentQuestion);
  }
  
  // Save last passage
  if (passageLines.length > 0) {
    const passageId = `english_${year}_passage_${passages.length + 1}`;
    passages.push({
      id: passageId,
      content: passageLines.join(' ').trim(),
      title: currentPassage || `Passage ${passages.length + 1}`,
      subject: 'english',
      examType: 'bece',
      year: year.toString(),
      section: currentSection,
      questionRange: '',
      createdBy: 'admin',
      isActive: true
    });
  }
  
  console.log(`✅ Parsed ${questions.length} questions, ${passages.length} passages`);
  return { questions, passages };
}

// Run if called directly
if (require.main === module) {
  const year = process.argv[2];
  
  if (!year) {
    console.log('Usage: node parse_english_pdf.js <year>');
    console.log('Example: node parse_english_pdf.js 2024');
    process.exit(1);
  }
  
  (async () => {
    const pdfPath = `./assets/bece English/bece english ${year} questions.pdf`;
    
    if (!fs.existsSync(pdfPath)) {
      console.log(`⚠️ File not found: ${pdfPath}`);
      process.exit(1);
    }
    
    try {
      const { questions, passages } = await parseEnglishPDF(pdfPath, year);
      
      // Save to JSON
      const outputData = { questions, passages };
      fs.writeFileSync(
        `english_${year}_questions.json`,
        JSON.stringify(outputData, null, 2)
      );
      console.log(`💾 Saved to english_${year}_questions.json`);
    } catch (error) {
      console.error(`❌ Error parsing ${year}:`, error.message);
      process.exit(1);
    }
  })();
}

module.exports = { parseEnglishPDF };
