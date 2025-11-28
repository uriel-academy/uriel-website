const mammoth = require('mammoth');
const fs = require('fs');

async function analyzeFrenchDocx() {
    const frenchFile = 'assets/bece french/bece french 2025 questions.docx';
    const englishFile = 'assets/bece English/bece english 2025 questions .docx';
    
    console.log('=== ANALYZING FRENCH 2025 ===\n');
    
    try {
        const frenchResult = await mammoth.extractRawText({ path: frenchFile });
        const frenchText = frenchResult.value;
        
        console.log('First 2000 characters:');
        console.log(frenchText.substring(0, 2000));
        console.log('\n...\n');
        console.log('Last 1000 characters:');
        console.log(frenchText.substring(frenchText.length - 1000));
        
        // Look for MCQ patterns
        const hasLetterOptions = /[A-D]\.\s+/.test(frenchText);
        const hasSectionLabels = /section|partie|part/i.test(frenchText);
        const hasComprehension = /comprehension|compr├⌐hension/i.test(frenchText);
        
        console.log('\n=== STRUCTURE ANALYSIS ===');
        console.log(`Has letter options (A. B. C. D.): ${hasLetterOptions}`);
        console.log(`Has section labels: ${hasSectionLabels}`);
        console.log(`Has comprehension: ${hasComprehension}`);
        console.log(`Total length: ${frenchText.length} characters`);
        
        // Save full text for manual review
        fs.writeFileSync('french_2025_full_text.txt', frenchText);
        console.log('\nFull text saved to: french_2025_full_text.txt');
        
    } catch (error) {
        console.error('Error analyzing French:', error.message);
    }
    
    console.log('\n\n=== ANALYZING ENGLISH 2025 (Reference) ===\n');
    
    try {
        const englishResult = await mammoth.extractRawText({ path: englishFile });
        const englishText = englishResult.value;
        
        console.log('First 2000 characters:');
        console.log(englishText.substring(0, 2000));
        console.log('\n...\n');
        console.log('Last 1000 characters:');
        console.log(englishText.substring(englishText.length - 1000));
        
        // Look for MCQ patterns
        const hasLetterOptions = /[A-D]\.\s+/.test(englishText);
        const hasSectionLabels = /section|part/i.test(englishText);
        const hasComprehension = /comprehension/i.test(englishText);
        
        console.log('\n=== STRUCTURE ANALYSIS ===');
        console.log(`Has letter options (A. B. C. D.): ${hasLetterOptions}`);
        console.log(`Has section labels: ${hasSectionLabels}`);
        console.log(`Has comprehension: ${hasComprehension}`);
        console.log(`Total length: ${englishText.length} characters`);
        
        // Save full text for manual review
        fs.writeFileSync('english_2025_full_text.txt', englishText);
        console.log('\nFull text saved to: english_2025_full_text.txt');
        
    } catch (error) {
        console.error('Error analyzing English:', error.message);
    }
}

analyzeFrenchDocx();
