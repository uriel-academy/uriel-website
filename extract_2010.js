const mammoth = require('mammoth');
const fs = require('fs');

async function extract() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2010  questions.docx'
    });
    
    fs.writeFileSync('french_2010_full.txt', result.value);
    console.log('Extracted to french_2010_full.txt');
}

extract();
