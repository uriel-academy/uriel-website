const fs = require('fs').promises;
const path = require('path');

async function checkExtracted() {
  const jsonFile = path.join('assets', 'bece_json', 'bece_integrated_science_questions.json');
  const data = await fs.readFile(jsonFile, 'utf8');
  const questions = JSON.parse(data);
  
  const q2022 = questions.filter(q => q.year === '2022');
  
  console.log('2022 Integrated Science extracted questions:\n');
  
  // Find duplicates
  const byNumber = {};
  q2022.forEach(q => {
    if (!byNumber[q.questionNumber]) byNumber[q.questionNumber] = [];
    byNumber[q.questionNumber].push(q);
  });
  
  console.log('Question numbers with duplicates:');
  Object.keys(byNumber).sort((a,b) => parseInt(a) - parseInt(b)).forEach(num => {
    if (byNumber[num].length > 1) {
      console.log(`\nQ${num}: ${byNumber[num].length} instances`);
      byNumber[num].forEach((q, idx) => {
        console.log(`  [${idx+1}] ${q.questionText.substring(0, 60)}...`);
      });
    }
  });
  
  // Show questions 26-30
  console.log('\n\n=== Questions 26-30 area ===');
  for (let i = 26; i <= 30; i++) {
    const qs = byNumber[i] || [];
    if (qs.length > 0) {
      console.log(`\nQ${i}: ${qs[0].questionText.substring(0, 80)}...`);
    } else {
      console.log(`\nQ${i}: MISSING`);
    }
  }
  
  // Check what question 28 in the file actually says
  console.log('\n\n=== The actual Q28 from file (labeled as "1") ===');
  const fake1 = byNumber[1]?.find(q => q.questionText.includes('ovary'));
  if (fake1) {
    console.log(`Question text: ${fake1.questionText}`);
    console.log(`Options:`, fake1.options);
    console.log(`Answer: ${fake1.correctAnswer}`);
  }
}

checkExtracted().catch(console.error);
