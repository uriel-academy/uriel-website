const fs = require('fs').promises;
const path = require('path');

async function main() {
  const jsonFile = path.join('assets', 'bece_json', 'bece_integrated_science_questions.json');
  const data = await fs.readFile(jsonFile, 'utf8');
  const questions = JSON.parse(data);
  
  const q2022 = questions.filter(q => q.year === '2022');
  
  console.log(`2022 Integrated Science: ${q2022.length} questions extracted\n`);
  
  if (q2022.length > 0) {
    console.log('Question numbers present:', q2022.map(q => q.questionNumber).sort((a,b) => a-b));
    
    console.log('\n\nSample questions:');
    q2022.slice(0, 5).forEach(q => {
      console.log(`\nQ${q.questionNumber}: ${q.questionText}`);
      console.log('Options:', q.options);
    });
  }
  
  // Find which question is missing
  const existing = new Set(q2022.map(q => q.questionNumber));
  const missing = [];
  for (let i = 1; i <= 40; i++) {
    if (!existing.has(i)) missing.push(i);
  }
  
  console.log(`\n\nMissing questions: ${missing.join(', ')}`);
}

main().catch(console.error);
