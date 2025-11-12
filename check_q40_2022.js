const mammoth = require('mammoth');
const path = require('path');

async function checkQ40() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value;
  
  console.log('Looking for question 40...\n');
  
  const q40Index = text.indexOf('\n40.\n');
  if (q40Index !== -1) {
    console.log('Found "\\n40.\\n" at position', q40Index);
    console.log('\nText around Q40:');
    console.log(text.substring(q40Index, Math.min(q40Index + 800, text.length)));
  } else {
    console.log('"\\n40.\\n" pattern NOT FOUND');
    
    // Look at the end of file
    console.log('\n\nLast 1000 characters of file:');
    console.log(text.substring(Math.max(0, text.length - 1000)));
  }
}

checkQ40().catch(console.error);
