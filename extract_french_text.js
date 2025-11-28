const mammoth = require('mammoth');
const fs = require('fs');

async function extractFullText() {
    const years = ['2001', '2002', '2008'];
    
    for (const year of years) {
        const file = `assets/bece french/bece  french ${year}  questions.docx`;
        
        if (!fs.existsSync(file)) {
            console.log(`File not found: ${file}`);
            continue;
        }
        
        const result = await mammoth.extractRawText({ path: file });
        const text = result.value;
        
        fs.writeFileSync(`french_${year}_full.txt`, text);
        console.log(`Saved: french_${year}_full.txt (${text.length} chars)`);
    }
}

extractFullText();
