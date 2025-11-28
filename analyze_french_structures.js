const mammoth = require('mammoth');
const fs = require('fs');

async function analyzeYearStructure(year) {
    const possibleFiles = [
        `assets/bece french/bece french ${year} questions.docx`,
        `assets/bece french/bece  french ${year} questions.docx`,
        `assets/bece french/bece  french ${year}  questions.docx`
    ];
    
    let filePath = null;
    for (const file of possibleFiles) {
        if (fs.existsSync(file)) {
            filePath = file;
            break;
        }
    }
    
    if (!filePath) {
        console.log(`${year}: File not found`);
        return;
    }
    
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    // Analyze structure
    const hasClosePassage = /The passage below has.*?numbered spaces/i.test(text);
    const hasComprehension = /quatre textes|Read the.*?texts below/i.test(text);
    const hasStandardMCQ = /For each question.*?choose from the options/i.test(text);
    
    // Count question markers
    const questionMatches = text.match(/^\d+\.\s+/gm) || [];
    const questionNumbers = [...new Set(questionMatches.map(m => parseInt(m.trim())))].sort((a, b) => a - b);
    
    // Check for table format (cloze)
    const hasTable = /\d+\s+[A-Za-zéèàôù]+\s+[A-Za-zéèàôù]+\s+[A-Za-zéèàôù]+\s+[A-Za-zéèàôù]+/.test(text);
    
    console.log(`\n${year}:`);
    console.log(`  Has cloze passage: ${hasClosePassage}`);
    console.log(`  Has comprehension: ${hasComprehension}`);
    console.log(`  Has standard MCQ: ${hasStandardMCQ}`);
    console.log(`  Has options table: ${hasTable}`);
    console.log(`  Question range: Q${questionNumbers[0]}-Q${questionNumbers[questionNumbers.length - 1]}`);
    console.log(`  Total unique questions: ${questionNumbers.length}`);
    
    // Save sample for manual inspection
    fs.writeFileSync(`french_${year}_sample.txt`, text.substring(0, 3000));
}

async function analyzeAll() {
    const years = ['2000', '2004', '2008', '2010', '2012', '2013', '2024', '2025'];
    
    console.log('=== ANALYZING FRENCH QUESTION STRUCTURES ===');
    
    for (const year of years) {
        await analyzeYearStructure(year);
    }
}

analyzeAll();
