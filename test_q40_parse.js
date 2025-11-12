const mammoth = require('mammoth');
const path = require('path');

// Copy the parseQuestionBlock function
function parseQuestionBlock(block, questionNumber, year, subject) {
  block = block.trim();
  if (!block) {
    console.log(`  Q${questionNumber}: Empty block`);
    return null;
  }
  
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
  
  console.log(`  Q${questionNumber}: text="${questionText.substring(0, 50)}...", options=${options.length}`);
  
  // Only return if we have valid question and at least 4 options
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
  
  console.log(`  Q${questionNumber}: FAILED validation (text=${!!questionText}, options=${options.length})`);
  return null;
}

async function testQ40() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  let text = result.value;
  text = text.replace(/\r/g, '');
  
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);
  
  console.log('Testing Q40 parsing:\n');
  
  // Find Q40
  for (let i = 0; i < blocks.length; i++) {
    if (blocks[i] === '40') {
      const questionBlock = blocks[i + 1];
      console.log('Q40 block content:');
      console.log('---');
      console.log(questionBlock);
      console.log('---\n');
      
      const result = parseQuestionBlock(questionBlock, 40, '2022', 'Integrated Science');
      
      if (result) {
        console.log('\n✅ Q40 PARSED SUCCESSFULLY');
        console.log(JSON.stringify(result, null, 2));
      } else {
        console.log('\n❌ Q40 FAILED TO PARSE');
      }
      
      break;
    }
  }
}

testQ40().catch(console.error);
