const mammoth = require('mammoth');
const fs = require('fs');

async function extract(year) {
    const result = await mammoth.extractRawText({
        path: `assets/bece french/bece  french ${year}  questions.docx`
    });
    
    fs.writeFileSync(`french_${year}_full.txt`, result.value);
    console.log(`${year}: Extracted ${result.value.length} characters`);
    
    // Check for "A B C D" tables
    const tableCount = (result.value.match(/A\s+B\s+C\s+D/g) || []).length;
    console.log(`  Tables: ${tableCount}`);
    
    // Check for numbered questions
    const questionMatches = result.value.match(/^\d+\./gm);
    console.log(`  Question lines: ${questionMatches ? questionMatches.length : 0}`);
}

async function main() {
    await extract('2015');
    await extract('2016');
}

main();
