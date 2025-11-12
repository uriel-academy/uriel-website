const fs = require('fs').promises;
const path = require('path');

async function checkYear(year) {
  const jsonFile = path.join('assets', 'bece_json', 'bece_social_studies_questions.json');
  const data = await fs.readFile(jsonFile, 'utf8');
  const questions = JSON.parse(data);
  
  const yearQuestions = questions.filter(q => q.year === year.toString());
  
  console.log(`\n${year}: ${yearQuestions.length} questions`);
  console.log('Question numbers:', yearQuestions.map(q => q.questionNumber).sort((a,b) => a-b));
  
  if (yearQuestions.length < 40) {
    // Find missing numbers
    const existing = new Set(yearQuestions.map(q => q.questionNumber));
    const missing = [];
    for (let i = 1; i <= 40; i++) {
      if (!existing.has(i)) missing.push(i);
    }
    console.log('Missing:', missing);
  }
  
  // Show first 3 questions
  console.log('\nFirst 3 questions:');
  yearQuestions.slice(0, 3).forEach(q => {
    console.log(`Q${q.questionNumber}: ${q.questionText.substring(0, 80)}...`);
    console.log(`  Options: ${q.options.length}`);
  });
}

async function main() {
  await checkYear(1991);
  await checkYear(1992);
  await checkYear(1993);
}

main().catch(console.error);
