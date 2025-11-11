const fs = require('fs');
const readline = require('readline');

/**
 * Interactive script to add correct answers to English questions JSON
 * 
 * Usage: node add_answers_to_json.js english_2022_questions.json
 * 
 * Enter answers as: 1D 2A 3B 4C... (question number followed by answer letter)
 * Or enter them one by one when prompted
 */

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, (answer) => {
      resolve(answer);
    });
  });
}

async function addAnswersInteractive(jsonPath) {
  console.log('📝 Interactive Answer Entry for BECE English\n');
  console.log('═══════════════════════════════════════════\n');
  
  if (!fs.existsSync(jsonPath)) {
    console.error(`❌ Error: File not found: ${jsonPath}`);
    rl.close();
    return;
  }
  
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  console.log(`✓ Loaded ${data.questions.length} questions from ${jsonPath}\n`);
  
  // Check how many already have answers
  const withAnswers = data.questions.filter(q => q.correctAnswer && q.correctAnswer.length > 0);
  console.log(`   ${withAnswers.length} questions already have answers`);
  console.log(`   ${data.questions.length - withAnswers.length} questions need answers\n`);
  
  const mode = await question('Choose mode:\n  1. Batch entry (e.g., "1D 2A 3B 4C...")\n  2. One-by-one entry\n  3. Skip\n\nEnter choice (1/2/3): ');
  
  if (mode === '1') {
    console.log('\n📋 Batch Answer Entry');
    console.log('Enter answers in format: 1D 2A 3B 4C 5A 6B...');
    console.log('Press Enter when done\n');
    
    const batchInput = await question('Answers: ');
    const answers = batchInput.trim().split(/\s+/);
    
    let updated = 0;
    answers.forEach(ans => {
      const match = ans.match(/^(\d+)([A-D])$/i);
      if (match) {
        const qNum = parseInt(match[1]);
        const answer = match[2].toUpperCase();
        
        const question = data.questions.find(q => q.questionNumber === qNum);
        if (question) {
          question.correctAnswer = answer;
          updated++;
        }
      }
    });
    
    console.log(`\n✓ Updated ${updated} answers`);
    
  } else if (mode === '2') {
    console.log('\n📝 One-by-one Entry');
    console.log('Enter answer (A/B/C/D) or press Enter to skip\n');
    
    for (const q of data.questions) {
      if (q.correctAnswer && q.correctAnswer.length > 0) {
        console.log(`Q${q.questionNumber}: ${q.correctAnswer} (already set)`);
        continue;
      }
      
      console.log(`\nQ${q.questionNumber}: ${q.questionText}`);
      q.options.forEach(opt => console.log(`  ${opt}`));
      
      const answer = await question('Answer: ');
      if (answer.trim().length > 0) {
        q.correctAnswer = answer.trim().toUpperCase();
      }
    }
  } else {
    console.log('\n⏭️  Skipping answer entry');
    rl.close();
    return;
  }
  
  // Save the updated JSON
  const backupPath = jsonPath.replace('.json', '_backup.json');
  fs.writeFileSync(backupPath, fs.readFileSync(jsonPath, 'utf8'));
  console.log(`\n💾 Created backup: ${backupPath}`);
  
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2), 'utf8');
  console.log(`✅ Saved updated file: ${jsonPath}`);
  
  // Show summary
  const finalWithAnswers = data.questions.filter(q => q.correctAnswer && q.correctAnswer.length > 0);
  console.log(`\n📊 Summary:`);
  console.log(`   Total questions: ${data.questions.length}`);
  console.log(`   With answers: ${finalWithAnswers.length}`);
  console.log(`   Missing answers: ${data.questions.length - finalWithAnswers.length}`);
  
  rl.close();
}

// Main
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log('Usage: node add_answers_to_json.js <json_file>');
  console.log('\nExample:');
  console.log('  node add_answers_to_json.js english_2022_questions.json');
  process.exit(0);
}

addAnswersInteractive(args[0]);
