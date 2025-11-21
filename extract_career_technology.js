const mammoth = require('mammoth');
const fs = require('fs').promises;
const path = require('path');

// Enhanced parser for Career Technology questions (4 options: A, B, C, D)
function parseQuestions(text, year, subject) {
  const questions = [];

  // Clean up text
  text = text.replace(/\r/g, '');

  // Find question number patterns (1., 2., 3., etc.)
  const numberPattern = /\n\n(\d+)\.\s*\n\n/g;
  let numberMatches = [];
  let match;

  while ((match = numberPattern.exec(text)) !== null) {
    numberMatches.push({
      number: parseInt(match[1]),
      index: match.index
    });
  }

  // Process each question
  for (let i = 0; i < numberMatches.length; i++) {
    const currentMatch = numberMatches[i];
    const nextMatch = numberMatches[i + 1];

    // Extract block from current question to next question (or end)
    const blockStart = currentMatch.index;
    const blockEnd = nextMatch ? nextMatch.index : text.length;
    const block = text.substring(blockStart, blockEnd);

    const question = parseQuestionBlock(block, currentMatch.number, year, subject);
    if (question) {
      questions.push(question);
    }
  }

  return questions;
}

function parseQuestionBlock(block, questionNumber, year, subject) {
  block = block.trim();
  if (!block) return null;

  // Find where options start (look for "A.  ")
  const aPos = block.search(/A\.\s\s/);
  if (aPos === -1) return null;

  // Question text is before "A.  "
  let questionText = block.substring(0, aPos).trim();

  // Remove question number if present (e.g., "1.\n\n")
  questionText = questionText.replace(/^\d+\.\s*\n*/, '').trim();

  // Extract options (A, B, C, D only)
  const optionsText = block.substring(aPos);
  const options = [];

  const optionRegex = /([A-D])\.\s\s(.+?)(?=[A-D]\.\s\s|$)/gs;
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
      options: options.slice(0, 4), // Only A, B, C, D
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

async function processCareerTechnology() {
  console.log('🔧 Processing Career Technology questions...\n');

  const subjectFolder = 'assets/bece Career Technology';
  const subjectName = 'Career Technology';

  try {
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
    console.log(`Answer file: ${answerFile || 'Not found'}`);

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

    const outputFile = path.join(outputDir, 'bece_career_technology_questions.json');
    await fs.writeFile(outputFile, JSON.stringify(allQuestions, null, 2));

    console.log(`\n✅ Saved ${allQuestions.length} Career Technology questions to ${outputFile}`);

    return allQuestions;

  } catch (error) {
    console.error('Error processing Career Technology:', error);
    throw error;
  }
}

async function main() {
  console.log('🚀 Starting Career Technology DOCX to JSON conversion...\n');

  try {
    const questions = await processCareerTechnology();

    console.log('\n📊 Summary:');
    console.log(`Career Technology: ${questions.length} questions`);

    if (questions.length !== 80) {
      console.log(`⚠️  Warning: Expected 80 questions but found ${questions.length}`);
    } else {
      console.log('✅ All 80 questions extracted successfully!');
    }

    console.log('\n✨ Conversion complete!');

  } catch (error) {
    console.error('❌ Conversion failed:', error);
    process.exit(1);
  }
}

main();