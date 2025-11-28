const mammoth = require('mammoth');

async function test() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const text = result.value;
    
    // Test: Can we identify that Q15 has 4 options by looking for article patterns?
    const q15Options = "la bibliothèque la librairie l'église l'hôtel";
    
    console.log('Q15 options:', q15Options);
    
    // Strategy: Look for article patterns (la, le, l', les, un, une, des, etc.)
    // Or count capital letters that start phrases
    // Or look for the pattern that options are separated by spaces before articles
    
    // Try splitting by common article patterns
    const articlePattern = /\b(la|le|l'|les|un|une|des|du|de|au|aux)\s+/gi;
    const parts = q15Options.split(articlePattern).filter(p => p && p.trim());
    console.log('Split by articles:', parts);
    
    // Better approach: Look for "article + word" patterns
    const matches = q15Options.match(/(?:la|le|l'|les|un|une|des|du|de|au|aux)\s+[\wé']+/gi);
    console.log('Matched phrases:', matches);
    
    // Test on Q11 (simple single words)
    const q11Options = "sommeil soif peur faim";
    const q11Parts = q11Options.split(/\s+/);
    console.log('\nQ11 simple:', q11Parts);
}

test();
