const fs = require('fs');
const mammoth = require('mammoth');

async function compareFrenchAndEnglish() {
    console.log('=== COMPARING FRENCH AND ENGLISH STRUCTURE ===\n');
    
    // Extract French 2000 (has 40 MCQ)
    console.log('--- FRENCH 2000 (Sample) ---');
    const frenchResult = await mammoth.extractRawText({ 
        path: 'assets/bece french/bece  french 2000 questions.docx' 
    });
    const frenchText = frenchResult.value;
    const frenchLines = frenchText.split('\n').slice(0, 100); // First 100 lines
    console.log(frenchLines.join('\n'));
    
    console.log('\n\n--- ENGLISH 2000 (Sample) ---');
    const englishResult = await mammoth.extractRawText({ 
        path: 'assets/bece English/bece english 2000 questions.docx' 
    });
    const englishText = englishResult.value;
    const englishLines = englishText.split('\n').slice(0, 100); // First 100 lines
    console.log(englishLines.join('\n'));
    
    // Save full extracts for detailed analysis
    fs.writeFileSync('french_2000_extract.txt', frenchText);
    fs.writeFileSync('english_2000_extract.txt', englishText);
    
    console.log('\n\nFull extracts saved to:');
    console.log('- french_2000_extract.txt');
    console.log('- english_2000_extract.txt');
}

compareFrenchAndEnglish().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
