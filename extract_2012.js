const mammoth = require('mammoth');
const fs = require('fs');

async function extract() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    fs.writeFileSync('french_2012_full.txt', result.value);
    console.log('Extracted, length:', result.value.length);
}

extract();
