const mammoth = require('mammoth');
const fs = require('fs').promises;
const path = require('path');

// Helper function to parse a single question block
function parseQuestionBlock(block, questionNumber, year, subject) {
  block = block.trim();
  if (!block) return null;
  
  let questionText = '';
  let options = [];
  
  // Check if options are inline (e.g., "Question text?A.  opt1B.  opt2...")
  const inlineMatch = block.match(/^(.+?)([A-E]\.\s+.+)$/s);
  
  if (inlineMatch) {
    // Inline format
    questionText = inlineMatch[1].trim();
    const optionsText = inlineMatch[2];
    
    // Extract options: "A.  option1B.  option2..."
    const optionRegex = /([A-E])\.\s+(.+?)(?=[A-E]\.\s+|$)/gs;
    let match;
    
    while ((match = optionRegex.exec(optionsText)) !== null) {
      const optionText = match[2].trim();
      if (optionText) {
        options.push(`${match[1]}. ${optionText}`);
      }
    }
  } else {
    // Newline-separated format
    const lines = block.split('\n').map(l => l.trim()).filter(l => l);
    
    let i = 0;
    // Get question text (everything until we hit an option marker)
    while (i < lines.length && !lines[i].match(/^[A-E]\.\s*$/)) {
      questionText += (questionText ? ' ' : '') + lines[i];
      i++;
    }
    
    // Parse options
    while (i < lines.length) {
      if (lines[i].match(/^[A-E]\.\s*$/)) {
        const letter = lines[i].charAt(0);
        i++;
        if (i < lines.length && !lines[i].match(/^[A-E]\.\s*$/) && !lines[i].match(/^\d+\.$/)) {
          options.push(`${letter}. ${lines[i]}`);
          i++;
        }
      } else {
        i++;
      }
    }
  }
  
  // Only return if we have valid question and at least 4 options
  if (questionText && options.length >= 4) {
    return {
      questionNumber,
      questionText,
      options: options.slice(0, 5), // Max 5 options (A-E)
      year: year.toString(),
      subject,
      examType: 'bece'
    };
  }
  
  return null;
}

// Main parser function
function parseQuestions(text, year, subject) {
  const questions = [];
  
  // Clean up text
  text = text.replace(/\r/g, '');
  
  // Split by question numbers that appear on their own line or with minimal spacing
  // Pattern matches: "\n2.\n" or "\n\n2.\n\n" 
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);


  
  if (blocks.length > 1) {
    // blocks[0] might contain question 1 (if it's unnumbered)
    // blocks[1] = "2", blocks[2] = question 2 text
    // blocks[3] = "3", blocks[4] = question 3 text, etc.
    
    // Try to parse question 1 from blocks[0]
    if (blocks[0].trim()) {
      const q1 = parseQuestionBlock(blocks[0], 1, year, subject);
      if (q1) {
        questions.push(q1);
      }
    }
    
    // Parse remaining numbered questions
    for (let i = 1; i < blocks.length; i += 2) {
      const questionNumber = parseInt(blocks[i]);
      const questionBlock = blocks[i + 1];
      
      // Skip if this looks like a false match (single digit after option text)
      // Check if previous block ends with an option pattern like "B.  "
      if (i > 1) {
        const prevBlock = blocks[i - 1];
        const prevEndMatch = prevBlock.trim().match(/[A-E]\.\s+[\d⁄]+\.?\s*$/);
        if (prevEndMatch && questionNumber >= 1 && questionNumber <= 9) {
          // This is likely "B.  \n\n1.\n" - skip it
          continue;
        }
      }
      
      if (questionBlock && questionNumber >= 1 && questionNumber <= 50) {
        const question = parseQuestionBlock(questionBlock, questionNumber, year, subject);
        if (question) {
          questions.push(question);
        }
      }
    }
  }
  
  // Sort by question number to ensure order
  questions.sort((a, b) => a.questionNumber - b.questionNumber);
  
  // Fix sequential numbering if we have duplicates or gaps
  // This handles cases where the DOCX has mislabeled question numbers
  if (questions.length >= 35) { // If we got most questions
    // Renumber sequentially
    const fixed = questions.map((q, index) => ({
      ...q,
      questionNumber: index + 1
    }));
    return fixed;
  }
  
  return questions;
}

// Helper to extract answers by year
function parseAnswersByYear(text) {
  const answersByYear = {};
  
  const lines = text.split('\n');
  let currentYear = null;
  
  for (const line of lines) {
    const trimmed = line.trim();
    
    // Check if this is a year header
    const yearMatch = trimmed.match(/^(\d{4})$/);
    if (yearMatch) {
      currentYear = yearMatch[1];
      answersByYear[currentYear] = {};
      continue;
    }
    
    // Check if this is an answer line (e.g., "1. A")
    const answerMatch = trimmed.match(/^(\d+)\.\s*([A-E])$/);
    if (answerMatch && currentYear) {
      const questionNumber = parseInt(answerMatch[1]);
      const answer = answerMatch[2];
      answersByYear[currentYear][questionNumber] = answer;
    }
  }
  
  return answersByYear;
}

async function convertDocxToText(docxPath) {
  try {
    const result = await mammoth.extractRawText({ path: docxPath });
    return result.value;
  } catch (error) {
    console.error(`Error reading ${docxPath}:`, error.message);
    return null;
  }
}

async function processSubject(subjectFolder, subjectName) {
  console.log(`\n📚 Processing ${subjectName}...`);
  
  const files = await fs.readdir(subjectFolder);
  const questionFiles = files.filter(f => 
    f.includes('questions') && f.endsWith('.docx') && !f.includes('~$')
  );
  const answerFile = files.find(f => 
    (f.toLowerCase().includes('answer') || f.match(/\d{4}-\d{4}\.docx$/)) && 
    f.endsWith('.docx') && 
    !f.includes('~$')
  );
  
  console.log(`Found ${questionFiles.length} question files`);
  
  // Load answers by year if available
  let answersByYear = {};
  if (answerFile) {
    console.log(`Loading answers from: ${answerFile}`);
    const answerText = await convertDocxToText(path.join(subjectFolder, answerFile));
    if (answerText) {
      answersByYear = parseAnswersByYear(answerText);
      console.log(`Parsed answers for ${Object.keys(answersByYear).length} years`);
    }
  }
  
  const allQuestions = [];
  
  for (const file of questionFiles.sort()) {
    // Extract year from filename
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) continue;
    
    const year = yearMatch[1];
    const filePath = path.join(subjectFolder, file);
    
    console.log(`Processing ${year}...`);
    
    const text = await convertDocxToText(filePath);
    if (!text) continue;
    
    const questions = parseQuestions(text, year, subjectName);
    
    // Add answers to questions from the year-specific answers
    const yearAnswers = answersByYear[year] || {};
    questions.forEach(q => {
      q.correctAnswer = yearAnswers[q.questionNumber];
    });
    
    allQuestions.push(...questions);
    console.log(`  ✓ Extracted ${questions.length} questions for ${year}`);
  }
  
  // Save to JSON
  const outputDir = path.join('assets', 'bece_json');
  await fs.mkdir(outputDir, { recursive: true });
  
  const outputFile = path.join(outputDir, `bece_${subjectName.toLowerCase().replace(/\s+/g, '_')}_questions.json`);
  await fs.writeFile(outputFile, JSON.stringify(allQuestions, null, 2));
  
  console.log(`\n✅ Saved ${allQuestions.length} questions to ${outputFile}`);
  
  return allQuestions;
}

async function main() {
  console.log('🚀 Starting DOCX to JSON conversion (v2 - Enhanced Parser)...\n');
  
  const assetsDir = 'assets';
  
  // Process Social Studies
  const socialStudiesDir = path.join(assetsDir, 'Social Studies');
  const socialStudiesQuestions = await processSubject(socialStudiesDir, 'Social Studies');
  
  // Process Integrated Science
  const integratedScienceDir = path.join(assetsDir, 'Integrated Science');
  const integratedScienceQuestions = await processSubject(integratedScienceDir, 'Integrated Science');
  
  console.log('\n📊 Summary:');
  console.log(`Social Studies: ${socialStudiesQuestions.length} questions`);
  console.log(`Integrated Science: ${integratedScienceQuestions.length} questions`);
  console.log(`Total: ${socialStudiesQuestions.length + integratedScienceQuestions.length} questions`);
  
  console.log('\n✨ Conversion complete!');
}

main().catch(console.error);
