const mammoth = require('mammoth');

async function test() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const text = result.value;
    
    // Find all "A B C D" tables
    const tableRegex = /A\s+B\s+C\s+D\s*\n\s*(.+?)(?=\n\n|$)/gs;
    const tableMatches = [...text.matchAll(tableRegex)];
    
    console.log(`Found ${tableMatches.length} tables`);
    
    tableMatches.forEach((match, idx) => {
        console.log(`\n=== TABLE ${idx + 1} ===`);
        console.log(match[1].substring(0, 150));
    });
}

test();
