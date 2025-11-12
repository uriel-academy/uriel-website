const mammoth = require('mammoth');
const path = require('path');

async function analyze2022() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value;
  
  console.log('=== ANALYZING 2022 INTEGRATED SCIENCE ===\n');
  
  // Count different option patterns
  const patterns = {
    'A.\\s\\s': 0,  // "A.  " (two spaces)
    'A\\.\\n': 0,   // "A.\n" (newline)
  };
  
  let match;
  const doubleSpacePattern = /A\.\s\s/g;
  while ((match = doubleSpacePattern.exec(text)) !== null) {
    patterns['A.\\s\\s']++;
  }
  
  const newlinePattern = /A\.\n/g;
  while ((match = newlinePattern.exec(text)) !== null) {
    patterns['A.\\n']++;
  }
  
  console.log('Option patterns found:');
  console.log(`  "A.  " (double space): ${patterns['A.\\s\\s']}`);
  console.log(`  "A.\\n" (newline): ${patterns['A.\\n']}`);
  
  // Check question number patterns
  const questionNumbers = [];
  const qNumPattern = /\n(\d+)\.\s*\n/g;
  while ((match = qNumPattern.exec(text)) !== null) {
    questionNumbers.push(parseInt(match[1]));
  }
  
  console.log(`\nQuestion numbers found (\\n##.\\n pattern): ${questionNumbers.length}`);
  console.log('Numbers:', questionNumbers);
  
  // Check around question 27-28
  console.log('\n\n=== AREA AROUND QUESTION 27-28 ===');
  const q27Index = text.indexOf('\n27.\n');
  if (q27Index !== -1) {
    console.log('\nQuestion 27 area:');
    console.log(text.substring(q27Index, q27Index + 800));
  } else {
    console.log('Question 27 number pattern NOT FOUND');
    
    // Look for where 27 should be
    const q26Index = text.indexOf('\n26.\n');
    const q28Index = text.indexOf('\n28.\n');
    
    if (q26Index !== -1 && q28Index !== -1) {
      console.log('\n\nText BETWEEN Q26 and Q28:');
      console.log(text.substring(q26Index, q28Index + 800));
    }
  }
}

analyze2022().catch(console.error);
