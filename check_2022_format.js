const mammoth = require('mammoth');
const path = require('path');

async function main() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value;
  
  console.log('First 4000 characters of 2022 Integrated Science:');
  console.log('='.repeat(80));
  console.log(text.substring(0, 4000));
  console.log('='.repeat(80));
  
  // Check for questions 9 and 14 specifically
  console.log('\n\nSearching for Question 9...');
  const q9Start = text.indexOf('9.\n');
  if (q9Start !== -1) {
    console.log(text.substring(q9Start, q9Start + 500));
  }
  
  console.log('\n\nSearching for Question 14...');
  const q14Start = text.indexOf('14.\n');
  if (q14Start !== -1) {
    console.log(text.substring(q14Start, q14Start + 600));
  }
  
  // Count "A.  " patterns
  const aPattern = /A\.\s\s/g;
  let count = 0;
  while (aPattern.exec(text) !== null) count++;
  console.log(`\n\nTotal "A.  " patterns found: ${count}`);
}

main().catch(console.error);
