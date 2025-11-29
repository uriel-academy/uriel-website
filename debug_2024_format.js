const fs = require('fs');

const text = fs.readFileSync('french_2024_full.txt', 'utf-8');
const lines = text.split('\n');

// Find Q2
for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === '2.') {
        console.log(`Found "2." at line ${i}`);
        for (let j = i+1; j <= i+5; j++) {
            console.log(`Line ${j} (len=${lines[j].length}): "${lines[j].substring(0, 100)}"`);
        }
        
        // Find the first non-empty line
        let contentLine = i+1;
        while (contentLine < lines.length && !lines[contentLine].trim()) {
            contentLine++;
        }
        
        console.log(`\nFirst non-empty line after "2.": ${contentLine}`);
        const nextLine = lines[contentLine].trim();
        console.log(`Content: "${nextLine.substring(0, 100)}"`);
        
        // Try to match
        const inlineMatch = nextLine.match(/^(.+?)([A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?)$/);
        console.log(`\nInline match:`, inlineMatch ? 'YES' : 'NO');
        
        if (inlineMatch) {
            console.log(`Question: "${inlineMatch[1]}"`);
            console.log(`Options: "${inlineMatch[2].substring(0, 80)}..."`);
        }
        
        break;
    }
}
