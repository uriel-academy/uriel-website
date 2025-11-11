const fs = require('fs');

// Add placeholder answers (all 'A') so we can import questions now
// You should update with correct answers from the PDF later

const jsonPath = './english_2022_questions.json';
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

console.log(`📝 Adding placeholder answers to ${data.questions.length} questions...\n`);

data.questions.forEach(q => {
  if (!q.correctAnswer || q.correctAnswer === '') {
    q.correctAnswer = 'A'; // Placeholder - update with real answer later
  }
});

// Backup original
fs.writeFileSync(jsonPath.replace('.json', '_no_answers.json'), JSON.stringify(data, null, 2));
console.log('✓ Created backup without answers');

// Save with placeholder answers
fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
console.log(`✓ Added placeholder answers to all questions`);
console.log(`\n⚠️  WARNING: All answers are set to 'A' as placeholders`);
console.log(`   Please update with correct answers from the PDF before importing!`);
console.log(`\n   You can either:`);
console.log(`   1. Edit the JSON file directly`);
console.log(`   2. Run: node add_answers_to_json.js english_2022_questions.json`);
console.log(`   3. Import now and update via admin panel later`);
