const fs = require('fs');

const text = fs.readFileSync('french_2012_full.txt', 'utf8');

const matches = [...text.matchAll(/A\s+B\s+C\s+D/g)];

console.log(`Found ${matches.length} "A B C D" occurrences`);

matches.forEach((m, idx) => {
    console.log(`\nMatch ${idx + 1} at position ${m.index}`);
    console.log('Context:', text.substring(m.index, m.index + 200));
});
