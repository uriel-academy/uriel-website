const mammoth = require('mammoth');
const fs = require('fs').promises;
const path = require('path');

// Helper to extract questions from DOCX text
function parseQuestions(text, year, subject) {
  const questions = [];
  
  // Clean up text
  text = text.replace(/\r/g, '');
  
  // First, try to split by question numbers that appear on their own line
  // Pattern: "\n\n2.\n\n" (question numbers 2-40)
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);
  
  // If we have blocks, process them
  if (blocks.length > 1) {
    // blocks[0] is text before first numbered question (might be question 1 without number)
    // blocks[1] is "2", blocks[2] is question 2 text, blocks[3] is "3", blocks[4] is question 3 text, etc.
    
    // Handle potential question 1 (unnumbered) in blocks[0]
    if (blocks[0].trim()) {
      const q1 = parseQuestionBlock(blocks[0], 1, year, subject);
      if (q1) questions.push(q1);
    }
    
    // Process remaining numbered questions
    for (let i = 1; i < blocks.length; i += 2) {
      const questionNumber = parseInt(blocks[i]);
      const questionBlock = blocks[i + 1];
      
      if (questionBlock) {
        const question = parseQuestionBlock(questionBlock, questionNumber, year, subject);
        if (question) questions.push(question);
      }
    }
  } else {
    // Fallback: try line-by-line parsing
    const lines = text.split('\n');
    let i = 0;
    while (i < lines.length) {
      const line = lines[i].trim();
      
      // Check if this is a question number (just "1." or "2." etc on its own line)
      const qNumMatch = line.match(/^(\d+)\.$/);
      if (qNumMatch) {
        const questionNumber = parseInt(qNumMatch[1]);
        i++; // Move past question number
      
      // Skip empty lines
      while (i < lines.length && lines[i].trim() === '') {
        i++;
      }
      
      if (i >= lines.length) break;
      
      // Get the question text (might be on one line or the next after blank lines)
      let questionText = '';
      while (i < lines.length) {
        const currentLine = lines[i].trim();
        // Stop when we hit an option marker
        if (currentLine.match(/^[A-E]\.\s*$/)) break;
        // Stop if it looks like an inline option (text ending with "A. ")
        if (currentLine.match(/[A-E]\.\s+\S/)) {
          // This is inline format - extract question and options together
          const optionMatch = currentLine.match(/^(.+?)([A-E]\.\s+.+)$/);
          if (optionMatch) {
            questionText = optionMatch[1].trim();
            const optionsText = optionMatch[2];
            
            // Extract all options inline
            const options = [];
            const optionRegex = /([A-E])\.\s+(.+?)(?=[A-E]\.\s+|$)/g;
            let match;
            
            while ((match = optionRegex.exec(optionsText)) !== null) {
              const optionText = match[2].trim();
              if (optionText) {
                options.push(`${match[1]}. ${optionText}`);
              }
            }
            
            if (questionText && options.length >= 4) {
              questions.push({
                questionNumber,
                questionText,
                options,
                year: year.toString(),
                subject,
                examType: 'bece'
              });
            }
            i++;
            break;
          }
        }
        if (!currentLine || currentLine === '') {
          break;
        }
        questionText += (questionText ? ' ' : '') + currentLine;
        i++;
      }
      
      // Skip empty lines after question
      while (i < lines.length && lines[i].trim() === '') {
        i++;
      }
      
      // Now extract options (if not already done in inline format)
      const options = [];
      while (i < lines.length) {
        const currentLine = lines[i].trim();
        
        // Check if this is an option marker (e.g., "A.")
        const optionMarker = currentLine.match(/^([A-E])\.\s*$/);
        if (optionMarker) {
          const letter = optionMarker[1];
          i++;
          
          // Skip empty lines
          while (i < lines.length && lines[i].trim() === '') {
            i++;
          }
          
          // Get option text
          if (i < lines.length) {
            const optionText = lines[i].trim();
            if (optionText && !optionText.match(/^\d+\.$/)) {
              options.push(`${letter}. ${optionText}`);
              i++;
            }
          }
          
          // Skip empty lines after option
          while (i < lines.length && lines[i].trim() === '') {
            i++;
          }
        } else {
          // No more options, break
          break;
        }
      }
      
      // Save question if we have all parts
      if (questionText && options.length >= 4) {
        questions.push({
          questionNumber,
          questionText,
          options,
          year: year.toString(),
          subject,
          examType: 'bece'
        });
      }
    } else {
      i++;
    }
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
  console.log('🚀 Starting DOCX to JSON conversion...\n');
  
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
