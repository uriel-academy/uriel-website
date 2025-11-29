const mammoth = require('mammoth');

async function extractTable() {
    const result = await mammoth.extractRawText({ 
        path: 'assets/bece french/bece  french 2015  questions.docx' 
    });
    
    const text = result.value;
    
    // Find text after "A.    B.    C.    D." header
    const match = text.match(/A\.\s+B\.\s+C\.\s+D\.(.+?)(?=PART|$)/s);
    
    if (match) {
        const tableText = match[1];
        console.log('Table text length:', tableText.length);
        console.log('\n--- Full table text ---');
        console.log(tableText);
        console.log('\n--- Split by numbers ---');
        
        // Try to find all occurrences of "11.", "12.", etc.
        const matches = tableText.matchAll(/(\d+)\.\s+(.+?)(?=\d+\.|$)/gs);
        for (const m of matches) {
            console.log(`\nQ${m[1]}: "${m[2].substring(0, 100)}..."`);
        }
    } else {
        console.log('No table found');
    }
}

extractTable().catch(console.error);
