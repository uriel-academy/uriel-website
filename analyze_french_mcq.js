const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');

async function analyzeFrenchFiles() {
    console.log('=== ANALYZING FRENCH DOCX FILES FOR MCQ ===\n');
    
    const frenchDir = 'assets/bece french';
    const files = fs.readdirSync(frenchDir)
        .filter(f => f.endsWith('.docx') && f.includes('questions'))
        .sort();
    
    console.log(`Found ${files.length} question files\n`);
    
    const filesWithMCQ = [];
    
    for (const file of files) {
        const year = file.match(/\d{4}/)?.[0];
        if (!year) continue;
        
        const filePath = path.join(frenchDir, file);
        
        try {
            const result = await mammoth.extractRawText({ path: filePath });
            const text = result.value;
            
            // Look for MCQ indicators:
            // - Letter options: A., B., C., D. or A) B) C) D)
            // - Multiple occurrences of these patterns
            const hasLetterOptions = /[A-D][\.)]\s+[^\n]{5,}/g.test(text);
            
            // Count potential MCQ questions by looking for numbered questions followed by options
            const mcqMatches = text.match(/\d+[\.)]\s+[^\n]+[\n\s]+[A-D][\.)]\s+/g);
            const estimatedMCQCount = mcqMatches ? mcqMatches.length : 0;
            
            // Also check for "SECTION" or "PART" which often indicates MCQ sections
            const hasSections = /SECTION|PART|PARTIE/i.test(text);
            
            if (hasLetterOptions || estimatedMCQCount > 0) {
                console.log(`✓ ${year}: Likely has MCQ`);
                console.log(`   Estimated MCQ questions: ${estimatedMCQCount}`);
                console.log(`   Has sections: ${hasSections}`);
                console.log(`   File: ${file}`);
                console.log();
                
                filesWithMCQ.push({
                    year,
                    file,
                    estimatedMCQCount,
                    hasSections,
                    filePath
                });
            }
        } catch (error) {
            console.log(`✗ ${year}: Error reading file - ${error.message}`);
        }
    }
    
    console.log('\n=== SUMMARY ===');
    console.log(`Files checked: ${files.length}`);
    console.log(`Files with MCQ: ${filesWithMCQ.length}`);
    const totalEstimatedMCQ = filesWithMCQ.reduce((sum, f) => sum + f.estimatedMCQCount, 0);
    console.log(`Total estimated MCQ questions: ${totalEstimatedMCQ}`);
    
    if (filesWithMCQ.length > 0) {
        console.log('\n=== FILES WITH MCQ ===');
        filesWithMCQ.forEach(f => {
            console.log(`${f.year}: ${f.estimatedMCQCount} MCQ questions`);
        });
        
        fs.writeFileSync(
            'french_mcq_analysis.json',
            JSON.stringify(filesWithMCQ, null, 2)
        );
        console.log('\nAnalysis saved to: french_mcq_analysis.json');
    }
}

analyzeFrenchFiles().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
