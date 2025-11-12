const mammoth = require('mammoth');
const path = require('path');

async function main() {
  const filePath = path.join('assets', 'Social Studies', 'bece social studies 1991 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value;
  
  // Find all "A.  " positions
  const optionAPattern = /A\.\s\s/g;
  let matches = [];
  let match;
  
  while ((match = optionAPattern.exec(text)) !== null) {
    matches.push(match.index);
  }
  
  // Check questions 13, 28, 31 (the missing ones)
  const checkQuestions = [12, 27, 30]; // 0-indexed (13, 28, 31)
  
  for (const idx of checkQuestions) {
    console.log(`\n=== Question ${idx + 1} ===`);
    const optionStart = matches[idx];
    const nextOptionStart = idx < matches.length - 1 ? matches[idx + 1] : text.length;
    
    let questionStart = 0;
    if (idx > 0) {
      const prevOptionsEnd = matches[idx - 1];
      const betweenText = text.substring(prevOptionsEnd, optionStart);
      
      const numberMatch = betweenText.match(/\n(\d+)\.\s*\n/);
      if (numberMatch) {
        questionStart = prevOptionsEnd + betweenText.indexOf(numberMatch[0]) + 1;
      } else {
        questionStart = prevOptionsEnd;
      }
    }
    
    const questionBlock = text.substring(questionStart, nextOptionStart);
    
    console.log('Block length:', questionBlock.length);
    console.log('Block:');
    console.log(questionBlock);
    console.log('\n--- End of Block ---');
  }
}

main().catch(console.error);
