const mammoth = require('mammoth');

async function analyzeYear(year) {
    const filePath = `assets/bece french/bece french ${year} questions.docx`;
    
    console.log(`\n=== Year ${year} ===`);
    
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    console.log(`Total length: ${text.length} characters`);
    console.log(`\nFirst 500 characters:`);
    console.log(text.substring(0, 500));
    console.log(`\n...`);
    
    // Check for different patterns
    console.log(`\nPattern Analysis:`);
    console.log(`  "A B C D" tables: ${(text.match(/A\s+B\s+C\s+D/g) || []).length}`);
    console.log(`  "A.  B.  C.  D." tables: ${(text.match(/A\.\s+B\.\s+C\.\s+D\./g) || []).length}`);
    console.log(`  "___N___" cloze blanks: ${(text.match(/___\d+___/g) || []).length}`);
    console.log(`  "– N –" cloze blanks: ${(text.match(/–\s*\d+\s*–/g) || []).length}`);
    console.log(`  Question numbers (1., 2., etc.): ${(text.match(/^\d+\./gm) || []).length}`);
    console.log(`  PART sections: ${(text.match(/PART [IVX]+/g) || []).length}`);
    
    // Sample a few question numbers
    console.log(`\nSample lines with question numbers:`);
    const lines = text.split('\n');
    let sampleCount = 0;
    for (const line of lines) {
        if (line.match(/^\d+\./)) {
            console.log(`  ${line.substring(0, 80)}...`);
            sampleCount++;
            if (sampleCount >= 5) break;
        }
    }
}

async function main() {
    await analyzeYear('2024');
    await analyzeYear('2025');
}

main().catch(console.error);
