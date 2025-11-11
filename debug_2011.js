const fs = require('fs');

const rawText = fs.readFileSync('extracted_english/english_2011_raw.txt', 'utf8');

// Apply same preprocessing
let processed = rawText.replace(/SECTION\s*([A-E])/gi, '\n\nSECTION $1\n');
processed = processed.replace(/([A-E])\.\s{2}/g, '\n$1.  ');
processed = processed.replace(/LEXIS AND STRUCTURE/gi, '\n\nLEXIS AND STRUCTURE\n');

const lines = processed.split('\n').map(l => l.trim()).filter(l => l.length > 0);

const questionLines = lines.filter(l => /^\d+\.$/.test(l));
console.log(`Found ${questionLines.length} question numbers`);
console.log('First 10:', questionLines.slice(0, 10));
console.log('\nFirst 20 non-empty lines:');
lines.slice(0, 20).forEach((l, i) => console.log(`${i}: ${l.substring(0, 60)}`));
