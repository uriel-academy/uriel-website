const mammoth = require('mammoth');
const fs = require('fs');

async function extractFull(year) {
    const filePath = `assets/bece french/bece french ${year} questions.docx`;
    
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    fs.writeFileSync(`french_${year}_full.txt`, text);
    console.log(`Wrote french_${year}_full.txt (${text.length} chars)`);
}

async function main() {
    await extractFull('2024');
    await extractFull('2025');
}

main().catch(console.error);
