const mammoth = require('mammoth');
const fs = require('fs');

async function extractFrenchAnswers() {
    console.log('Extracting French answer key...\n');
    
    const result = await mammoth.extractRawText({ 
        path: 'assets/bece french/bece  french 1990-2016-2024-2025 answers.docx' 
    });
    
    const text = result.value;
    console.log(text);
    
    fs.writeFileSync('french_answers_extract.txt', text);
    console.log('\n\nSaved to: french_answers_extract.txt');
}

extractFrenchAnswers().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
