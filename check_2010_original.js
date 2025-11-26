const fs = require('fs');

const data = JSON.parse(fs.readFileSync('bece_theory_english.json', 'utf8'));

const year2010 = data.filter(q => q.year === 2010);

console.log('2010 Original Questions from JSON:');
console.log('='.repeat(80));
year2010.forEach((q) => {
  console.log(`\nQ${q.questionNumber}:`);
  console.log(q.questionText);
  console.log('-'.repeat(80));
});
