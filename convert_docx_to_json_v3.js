const mammoth = require('mammoth');
const fs = require('fs').promises;
const path = require('path');

// Enhanced parser - simpler approach: find "E.  " patterns to mark end of each question
function parseQuestions(text, year, subject) {
  const questions = [];
  
  // Clean up text
  text = text.replace(/\r/g, '');
  
  // Find all option patterns
  const aPattern = /A\.\s\s/g;
  const ePattern = /E\.\s\s/g;
  
  let aMatches = [];
  let eMatches = [];
  let match;
  
  while ((match = aPattern.exec(text)) !== null) {
    aMatches.push(match.index);
  }
  
  while ((match = ePattern.exec(text)) !== null) {
    eMatches.push(match.index);
  }
  
  // Each question has one "A.  " and typically one "E.  "
  // Extract from "A.  " to the corresponding "E.  " (or next "A.  ")
  
  for (let i = 0; i < aMatches.length; i++) {
    const aPos = aMatches[i];
    
    // Find the "E.  " that belongs to this question
    const ePos = eMatches.find(e => e > aPos && (i === aMatches.length - 1 || e < aMatches[i + 1]));
    
    if (!ePos) continue; // Skip if no "E.  " found
    
    // Now find where the question text starts (before "A.  ")
    let questionStart = 0;
    
    if (i === 0) {
      // First question - starts at beginning
      questionStart = 0;
    } else {
      // Find the end of previous question's options (previous "E.  ")
      const prevE = eMatches[i - 1];
      if (prevE) {
        // Find the content after previous "E.  " pattern
        const searchStart = prevE + 4; // After "E.  "
        // Look for newlines and the next content
        const afterPrevE = text.substring(searchStart, aPos);
        
        // Find where actual question text starts (after option text and number)
        // Pattern: "option text\n\nN.\n\nQuestion text"
        const numMatch = afterPrevE.match(/\n\n(\d+)\.\s*\n\n/);
        if (numMatch) {
          questionStart = searchStart + afterPrevE.indexOf(numMatch[0]) + numMatch[0].length;
        } else {
          // No number, just skip whitespace after prev E
          questionStart = searchStart + afterPrevE.search(/\S/);
          if (questionStart < searchStart) questionStart = searchStart;
        }
      }
    }
    
    // Extract block from question start through all options
    const blockEnd = ePos + 100; // Include option E text
    const block = text.substring(questionStart, Math.min(blockEnd, text.length));
    
    const question = parseQuestionBlock(block, i + 1, year, subject);
    if (question) {
      questions.push(question);
    }
  }
  
  return questions;
}

function parseQuestionBlock(block, questionNumber, year, subject) {
  block = block.trim();
  if (!block) return null;
  
  // Find where options start
  const aPos = block.search(/A\.\s\s/);
  if (aPos === -1) return null;
  
  // Question text is before "A.  "
  let questionText = block.substring(0, aPos).trim();
  
  // Remove question number if present
  questionText = questionText.replace(/^\d+\.\s*\n*/, '').trim();
  
  // Extract all 5 options
  const optionsText = block.substring(aPos);
  const options = [];
  
  const optionRegex = /([A-E])\.\s\s(.+?)(?=[A-E]\.\s\s|$)/gs;
  let match;
  
  while ((match = optionRegex.exec(optionsText)) !== null) {
    const letter = match[1];
    let optionText = match[2].trim();
    // Clean up - remove trailing newlines and question numbers
    optionText = optionText.replace(/\n\n\d+\.\s*\n[\s\S]*$/, '').trim();
    optionText = optionText.replace(/\n+/g, ' ').replace(/\s+/g, ' ');
    
    if (optionText) {
      options.push(`${letter}. ${optionText}`);
    }
  }
  
  // Clean question text
  questionText = questionText.replace(/\n+/g, ' ').replace(/\s+/g, ' ').trim();
  
  if (questionText && options.length >= 4) {
    return {
      questionNumber,
      questionText,
      options: options.slice(0, 5),
      year: year.toString(),
      subject,
      examType: 'bece'
    };
  }
  
  return null;
}

// Helper to extract answers by year
function parseAnswersByYear(text) {
  const answersByYear = {};
  
  const lines = text.split('\n');
  let currentYear = null;
  
  for (const line of lines) {
    const trimmed = line.trim();
    
    const yearMatch = trimmed.match(/^(\d{4})$/);
    if (yearMatch) {
      currentYear = yearMatch[1];
      answersByYear[currentYear] = {};
      continue;
    }
    
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
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) continue;
    
    const year = yearMatch[1];
    const filePath = path.join(subjectFolder, file);
    
    console.log(`Processing ${year}...`);
    
    const text = await convertDocxToText(filePath);
    if (!text) continue;
    
    const questions = parseQuestions(text, year, subjectName);
    
    const yearAnswers = answersByYear[year] || {};
    questions.forEach(q => {
      q.correctAnswer = yearAnswers[q.questionNumber];
    });
    
    allQuestions.push(...questions);
    console.log(`  ✓ Extracted ${questions.length} questions for ${year}`);
  }
  
  const outputDir = path.join('assets', 'bece_json');
  await fs.mkdir(outputDir, { recursive: true });
  
  const outputFile = path.join(outputDir, `bece_${subjectName.toLowerCase().replace(/\s+/g, '_')}_questions.json`);
  await fs.writeFile(outputFile, JSON.stringify(allQuestions, null, 2));
  
  console.log(`\n✅ Saved ${allQuestions.length} questions to ${outputFile}`);
  
  return allQuestions;
}

async function main() {
  console.log('🚀 Starting DOCX to JSON conversion (v3 - Option-Based Parser)...\n');
  
  const assetsDir = 'assets';
  
  const socialStudiesDir = path.join(assetsDir, 'Social Studies');
  const socialStudiesQuestions = await processSubject(socialStudiesDir, 'Social Studies');
  
  const integratedScienceDir = path.join(assetsDir, 'Integrated Science');
  const integratedScienceQuestions = await processSubject(integratedScienceDir, 'Integrated Science');
  
  console.log('\n📊 Summary:');
  console.log(`Social Studies: ${socialStudiesQuestions.length} questions`);
  console.log(`Integrated Science: ${integratedScienceQuestions.length} questions`);
  console.log(`Total: ${socialStudiesQuestions.length + integratedScienceQuestions.length} questions`);
  
  console.log('\n✨ Conversion complete!');
}

main().catch(console.error);
