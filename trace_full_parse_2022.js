const mammoth = require('mammoth');
const path = require('path');

function parseQuestionBlock(block, questionNumber, year, subject) {
  block = block.trim();
  if (!block) return null;
  
  let questionText = '';
  let options = [];
  
  const inlineMatch = block.match(/^(.+?)([A-E]\.\s+.+)$/s);
  
  if (inlineMatch) {
    questionText = inlineMatch[1].trim();
    const optionsText = inlineMatch[2];
    const optionRegex = /([A-E])\.\s+(.+?)(?=[A-E]\.\s+|$)/gs;
    let match;
    
    while ((match = optionRegex.exec(optionsText)) !== null) {
      const optionText = match[2].trim();
      if (optionText) {
        options.push(`${match[1]}. ${optionText}`);
      }
    }
  } else {
    const lines = block.split('\n').map(l => l.trim()).filter(l => l);
    
    let i = 0;
    while (i < lines.length && !lines[i].match(/^[A-E]\.\s*$/)) {
      questionText += (questionText ? ' ' : '') + lines[i];
      i++;
    }
    
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

async function traceParsing() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  let text = result.value;
  text = text.replace(/\r/g, '');
  
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);
  const questions = [];
  
  console.log(`blocks.length = ${blocks.length}\n`);
  
  // Try parse Q1 from blocks[0]
  if (blocks[0].trim()) {
    const q1 = parseQuestionBlock(blocks[0], 1, '2022', 'Integrated Science');
    if (q1) {
      questions.push(q1);
      console.log(`Parsed Q1 from blocks[0]`);
    }
  }
  
  // Parse numbered questions
  let parsedCount = 0;
  for (let i = 1; i < blocks.length; i += 2) {
    const questionNumber = parseInt(blocks[i]);
    const questionBlock = blocks[i + 1];
    
    if (questionBlock && questionNumber >= 1 && questionNumber <= 50) {
      const question = parseQuestionBlock(questionBlock, questionNumber, '2022', 'Integrated Science');
      if (question) {
        questions.push(question);
        parsedCount++;
        
        if (questionNumber >= 38) {
          console.log(`i=${i}, questionNumber=${questionNumber}, parsed successfully`);
        }
      } else if (questionNumber >= 38) {
        console.log(`i=${i}, questionNumber=${questionNumber}, FAILED to parse`);
      }
    }
  }
  
  console.log(`\nTotal parsed before sort: ${questions.length}`);
  
  questions.sort((a, b) => a.questionNumber - b.questionNumber);
  
  console.log(`Question numbers: ${questions.map(q => q.questionNumber).join(', ')}`);
  
  // Apply sequential fix
  if (questions.length >= 35) {
    const fixed = questions.map((q, index) => ({
      ...q,
      questionNumber: index + 1
    }));
    console.log(`\nAfter sequential renumbering: ${fixed.length} questions`);
    console.log(`Final numbers: ${fixed.map(q => q.questionNumber).join(', ')}`);
  }
}

traceParsing().catch(console.error);
