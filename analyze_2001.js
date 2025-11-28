const mammoth = require('mammoth');
const fs = require('fs');

async function analyze2001() {
    const possibleFiles = [
        'assets/bece french/bece french 2001 questions.docx',
        'assets/bece french/bece  french 2001 questions.docx',
        'assets/bece french/bece  french 2001  questions.docx'
    ];
    
    let filePath = null;
    for (const file of possibleFiles) {
        if (fs.existsSync(file)) {
            filePath = file;
            console.log(`Found: ${file}`);
            break;
        }
    }
    
    if (!filePath) {
        console.log('File not found');
        return;
    }
    
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    console.log('\n=== YEAR 2001 STRUCTURE ===\n');
    console.log('First 3000 characters:');
    console.log(text.substring(0, 3000));
    
    // Count questions
    const qMatches = [...text.matchAll(/^(\d+)\.\s+/gm)];
    const qNumbers = [...new Set(qMatches.map(m => parseInt(m[1])))].sort((a, b) => a - b);
    
    console.log(`\n\nTotal unique questions: ${qNumbers.length}`);
    console.log(`Question numbers: ${qNumbers.join(', ')}`);
    
    fs.writeFileSync('french_2001_full.txt', text);
    console.log('\nSaved to: french_2001_full.txt');
}

analyze2001();
