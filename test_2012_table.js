const mammoth = require('mammoth');

async function test() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const text = result.value;
    
    // Find the table after PART II
    const tableMatch = text.match(/A\s+B\s+C\s+D\s*\n\s*(.+?)(?=PART III)/s);
    if (tableMatch) {
        const tableText = tableMatch[1];
        console.log('Table text:', tableText);
        console.log('\n=== PARSING ===\n');
        
        // Try to parse: "11. opt opt opt opt12. opt opt opt opt"
        const questionRegex = /(\d+)\.\s*([^\d]+?)(?=\d+\.|$)/g;
        const matches = tableText.matchAll(questionRegex);
        
        for (const match of matches) {
            const qNum = match[1];
            const optionsText = match[2].trim();
            console.log(`Q${qNum}: "${optionsText}"`);
            
            const parts = optionsText.split(/\s+/).filter(p => p && p.length > 0);
            console.log(`  Parts (${parts.length}):`, parts.slice(0, 6));
        }
    }
}

test();
