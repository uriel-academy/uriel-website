const fs = require('fs');

const data = JSON.parse(fs.readFileSync('bece_theory_english.json', 'utf8'));

const year1990 = data.filter(q => q.year === 1990);
const year2025 = data.filter(q => q.year === 2025);

console.log('1990 Questions (4 total):');
console.log('='.repeat(80));
year1990.forEach((q, i) => {
  console.log(`\nQ${q.questionNumber}:`);
  console.log(q.questionText.substring(0, 200) + '...');
});

console.log('\n\n2025 Questions (5 total):');
console.log('='.repeat(80));
year2025.forEach((q, i) => {
  console.log(`\nQ${q.questionNumber}:`);
  console.log(q.questionText.substring(0, 200) + '...');
});
