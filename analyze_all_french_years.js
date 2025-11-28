const mammoth = require('mammoth');
const fs = require('fs');

async function analyzeFrenchYear(year) {
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
        console.log(`Year ${year}: File not found`);
        return;
    }
    
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    // Count questions
    const questionPattern = /^\d+\.\s+/gm;
    const questionMatches = text.match(questionPattern) || [];
    const questionNumbers = questionMatches.map(m => parseInt(m.trim().replace('.', '')));
    const uniqueQuestions = [...new Set(questionNumbers)].sort((a, b) => a - b);
    
    // Find MCQ section
    const hasMCQSection = /PART\s+1|Section\s+1|Objective/i.test(text);
    const hasTheorySection = /PART\s+2|Section\s+2|Essay/i.test(text);
    
    console.log(`\n=== Year ${year} ===`);
    console.log(`File: ${filePath}`);
    console.log(`Total length: ${text.length} chars`);
    console.log(`Question markers found: ${questionMatches.length}`);
    console.log(`Unique question numbers: ${uniqueQuestions.length}`);
    console.log(`Range: Q${uniqueQuestions[0]} - Q${uniqueQuestions[uniqueQuestions.length - 1]}`);
    console.log(`Has MCQ section marker: ${hasMCQSection}`);
    console.log(`Has Theory section marker: ${hasTheorySection}`);
    
    // Show first few questions
    if (uniqueQuestions.length > 0) {
        console.log(`First 5 questions: ${uniqueQuestions.slice(0, 5).join(', ')}`);
        console.log(`Last 5 questions: ${uniqueQuestions.slice(-5).join(', ')}`);
    }
}

async function analyzeAllYears() {
    const years = [
        '2000', '2001', '2002', '2003', '2004', '2005',
        '2006', '2007', '2008', '2009', '2010', '2011',
        '2012', '2013', '2014', '2015', '2016',
        '2024', '2025'
    ];
    
    console.log('=== ANALYZING ALL FRENCH YEARS ===');
    
    for (const year of years) {
        await analyzeFrenchYear(year);
    }
}

analyzeAllYears();
