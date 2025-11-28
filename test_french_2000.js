const mammoth = require('mammoth');
const fs = require('fs');

async function testYear2000() {
    const filePath = 'assets/bece french/bece  french 2000 questions.docx';
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    console.log('=== YEAR 2000 ANALYSIS ===\n');
    console.log('First 2000 characters:');
    console.log(text.substring(0, 2000));
    console.log('\n\n=== OPTIONS TABLE SECTION ===');
    
    // Find the options table
    const tableMatch = text.match(/A\s+B\s+C\s+D[\s\S]*?(?=For each|11\.)/);
    if (tableMatch) {
        console.log(tableMatch[0].substring(0, 1000));
    }
    
    // Count all questions
    const allQuestions = [...text.matchAll(/^(\d+)\.\s+/gm)];
    const uniqueQ = [...new Set(allQuestions.map(m => parseInt(m[1])))].sort((a, b) => a - b);
    
    console.log(`\n\nTotal unique questions found: ${uniqueQ.length}`);
    console.log(`Question numbers: ${uniqueQ.join(', ')}`);
    
    fs.writeFileSync('french_2000_full_analysis.txt', text);
    console.log('\nFull text saved to: french_2000_full_analysis.txt');
}

testYear2000();
