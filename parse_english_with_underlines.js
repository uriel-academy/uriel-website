const mammoth = require('mammoth');
const fs = require('fs');

/**
 * Enhanced parser for BECE English questions with underline support
 * Uses mammoth to extract formatted text from DOCX
 */

const SECTION_INSTRUCTIONS = {
  'COMPREHENSION': 'Read the following passages carefully and answer the questions that follow.',
  'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
  'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
  'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
  'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
  'E': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
};

async function parseEnglishQuestionsWithFormatting(docxPath, year) {
  console.log(`\n📖 Parsing ${year} with formatting...`);
  
  // Extract HTML with formatting preserved
  const result = await mammoth.convertToHtml(
    { path: docxPath },
    {
      styleMap: [
        "u => u",  // Map underline to <u> tag
        "i => em", // Map italic to <em> tag  
        "b => strong" // Map bold to <strong> tag
      ]
    }
  );
  
  let htmlText = result.value;
  
  // Convert HTML entities
  htmlText = htmlText
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
  
  // Extract text while preserving <u> tags
  let formattedText = htmlText
    .replace(/<p>/g, '\n')
    .replace(/<\/p>/g, '\n')
    .replace(/<br\s*\/?>/g, '\n')
    .replace(/<strong>/g, '')
    .replace(/<\/strong>/g, '')
    .replace(/<em>/g, '')
    .replace(/<\/em>/g, '')
    // Keep <u> tags for underlines
    .replace(/<u>/g, '<u>')
    .replace(/<\/u>/g, '</u>');
  
  // Pre-process sections
  formattedText = formattedText.replace(/PART\s+(I+|[IV]+)/gi, ''); // Remove PART markers
  formattedText = formattedText.replace(/LEXIS AND STRUCTURE/gi, ''); // Remove LEXIS markers
  formattedText = formattedText.replace(/SECTION\s*([A-E])/gi, '\n\nSECTION $1\n');
  formattedText = formattedText.replace(/COMPREHENSION/gi, '\n\nCOMPREHENSION\n');
  formattedText = formattedText.replace(/PASSAGE\s+(I+|[IV]+)/gi, '\n\nPASSAGE $1\n');
  
  // Split question numbers - handle inline format like "sentence.1.  One" or "sentence.  1.  One"
  // Match patterns: word.NUMBER.  or word.  NUMBER.
  formattedText = formattedText.replace(/([a-z])\.\s*(\d+)\.\s+/gi, '$1.\n\n$2.\n');
  formattedText = formattedText.replace(/([a-z])\s+(\d+)\.\s+/gi, '$1\n\n$2.\n');
  
  // Also handle start of line question numbers
  formattedText = formattedText.replace(/^(\d+)\.\s+/gm, '\n\n$1.\n');
  
  // Split options - more flexible
  formattedText = formattedText.replace(/([A-E])\.\s{1,}/g, '\n$1.  ');
  
  const lines = formattedText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const questions = [];
  const passages = [];
  let currentSection = 'A'; // Default to Section A for newer formats
  let currentPassage = null;
  let currentPassageId = null;
  let collectingPassage = false;
  let passageLines = [];
  let currentQuestion = null;
  let currentOptions = [];
  let pendingQuestionText = null; // Store question text when we see it before the number
  
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
    
    // Detect standalone question number (comes AFTER question text in 2019+ format)
    if (/^\d+\.$/.test(line)) {
      const questionNumber = parseInt(line.replace('.', ''));
      
      // Create question with pending text if available
      if (pendingQuestionText) {
        // Save previous question first
        if (currentQuestion && currentOptions.length >= 4) {
          currentQuestion.options = currentOptions.slice(0, currentSection === 'COMPREHENSION' ? 5 : 4);
          questions.push(currentQuestion);
        }
        
        currentQuestion = {
          id: `english_${year}_q${questionNumber}`,
          questionNumber,
          questionText: pendingQuestionText,
          options: [],
          correctAnswer: '',
          explanation: '',
          subject: 'english',
          examType: 'bece',
          year: year.toString(),
          section: currentSection,
          sectionInstructions: SECTION_INSTRUCTIONS[currentSection] || '',
          passageId: (currentSection === 'COMPREHENSION' && currentPassageId) ? currentPassageId : null,
          createdBy: 'admin',
          isActive: true
        };
        currentOptions = [];
        pendingQuestionText = null;
      }
      continue;
    }
    
    // Detect inline question with options (2019+ format: "question text.A. opt1B. opt2C. opt3D. opt4")
    const inlineMatch = line.match(/^(.+?)\s*A\.\s+(.+?)\s*B\.\s+(.+?)\s*C\.\s+(.+?)\s*D\.\s+(.+?)$/);
    if (inlineMatch) {
      // This is question text with inline options
      pendingQuestionText = inlineMatch[1].trim();
      // Store options temporarily
      currentOptions = [
        inlineMatch[2].trim(),
        inlineMatch[3].trim(),
        inlineMatch[4].trim(),
        inlineMatch[5].trim()
      ];
      continue;
    }
    
    // Detect options (traditional format)
    if (/^[A-E]\.\s+/.test(line) && currentQuestion) {
      const optionText = line.replace(/^[A-E]\.\s+/, '').trim();
      currentOptions.push(optionText);
      continue;
    }
    
    // Accumulate question text (with underline tags preserved)
    if (currentQuestion && currentOptions.length === 0 && line.length > 0) {
      currentQuestion.questionText += (currentQuestion.questionText ? ' ' : '') + line;
    } else if (!currentQuestion && line.length > 10 && !collectingPassage) {
      // Store as pending question text
      pendingQuestionText = line;
    }
  }
  
  // Save last question
  if (currentQuestion && currentOptions.length >= 4) {
    currentQuestion.options = currentOptions.slice(0, currentSection === 'COMPREHENSION' ? 5 : 4);
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
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('Usage: node parse_english_with_underlines.js <year or year-range>');
    console.log('Example: node parse_english_with_underlines.js 2019');
    console.log('Example: node parse_english_with_underlines.js 2019-2023');
    process.exit(1);
  }
  
  (async () => {
    let years = [];
    
    if (args[0].includes('-')) {
      const [start, end] = args[0].split('-').map(Number);
      for (let y = start; y <= end; y++) {
        years.push(y);
      }
    } else {
      years = [parseInt(args[0])];
    }
    
    for (const year of years) {
      const docxPath = `./assets/bece English/bece english ${year} questions.docx`;
      
      if (!fs.existsSync(docxPath)) {
        console.log(`⚠️ File not found: ${docxPath}`);
        continue;
      }
      
      try {
        const { questions, passages } = await parseEnglishQuestionsWithFormatting(docxPath, year);
        
        // Save to JSON
        const outputData = { questions, passages };
        fs.writeFileSync(
          `english_${year}_questions.json`,
          JSON.stringify(outputData, null, 2)
        );
        console.log(`💾 Saved to english_${year}_questions.json`);
      } catch (error) {
        console.error(`❌ Error parsing ${year}:`, error.message);
      }
    }
    
    console.log('\n✅ All done!');
  })();
}

module.exports = { parseEnglishQuestionsWithFormatting };
