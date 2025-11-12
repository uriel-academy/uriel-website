const mammoth = require('mammoth');
const path = require('path');

async function main() {
  const filePath = path.join('assets', 'Social Studies', 'bece social studies 1991 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value;
  
  console.log('First 3000 characters:');
  console.log('=' .repeat(80));
  console.log(text.substring(0, 3000));
  console.log('='.repeat(80));
  
  // Check "A.  " pattern
  const aPattern = /A\.\s\s/g;
  let count = 0;
  let match;
  while ((match = aPattern.exec(text)) !== null) {
    count++;
    if (count <= 5) {
      console.log(`\nMatch ${count} at position ${match.index}:`);
      console.log(text.substring(Math.max(0, match.index - 100), match.index + 200));
    }
  }
  console.log(`\nTotal "A.  " patterns: ${count}`);
}

main().catch(console.error);
