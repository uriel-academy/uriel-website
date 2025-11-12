const mammoth = require('mammoth');

async function checkFiles() {
  const years = ['1991', '1992', '1993'];
  
  for (const year of years) {
    const result = await mammoth.extractRawText({ 
      path: `assets/Social Studies/bece social studies ${year} questions.docx` 
    });
    
    const lines = result.value.split('\n');
    const hasNewlines = lines.length > 10;
    
    console.log(`\n${year} Social Studies:`);
    console.log(`  Total lines after split: ${lines.length}`);
    console.log(`  First line length: ${lines[0].length}`);
    console.log(`  Status: ${hasNewlines ? '✅ Has newlines' : '⚠️ Single line file'}`);
    
    // Check if we can find question numbers
    const text = result.value;
    const matches = text.match(/\d+\.\n\n/g);
    console.log(`  Question number patterns found: ${matches ? matches.length : 0}`);
    
    // Try to count questions by looking for "A.  " patterns (option A)
    const optionACount = (text.match(/A\.\s\s/g) || []).length;
    console.log(`  Option A patterns found: ${optionACount}`);
  }
}

checkFiles().then(() => process.exit(0));
