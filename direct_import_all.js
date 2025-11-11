const { execSync } = require('child_process');
const fs = require('fs');

/**
 * Process and import all years 1990-2018
 * Skips batch_process scripts that were causing corruption
 */

const years = [];
for (let y = 1990; y <= 2018; y++) {
  years.push(y);
}

console.log('🚀 Direct Process & Import English Questions');
console.log('═══════════════════════════════════════════\n');
console.log(`Processing ${years.length} years...\n`);

let successCount = 0;
let failedYears = [];

years.forEach(year => {
  const filePath = `./english_${year}_questions.json`;
  
  if (!fs.existsSync(filePath)) {
    console.log(`⏭️  Skipping ${year} - file not found`);
    failedYears.push(year);
    return;
  }
  
  try {
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const questionCount = data.questions.length;
    
    if (questionCount === 0) {
      console.log(`⏭️  Skipping ${year} - 0 questions`);
      failedYears.push(year);
      return;
    }
    
    console.log(`\n📅 Year ${year} (${questionCount} questions):`);
    
    // Process inline: add underlines, instructions, placeholders
    console.log('   🔧 Processing...');
    
    // Add underline markers
    data.questions.forEach(q => {
      if (q.section && ['B', 'C', 'D', 'E'].includes(q.section) && !q.questionText.includes('<u>')) {
        // Simple auto-underline for key words
        const words = q.questionText.match(/\b[a-z]{4,}\b/gi) || [];
        if (words.length > 0) {
          const keyWord = words[words.length - 1]; // Last significant word
          q.questionText = q.questionText.replace(new RegExp(`\\b${keyWord}\\b`, 'i'), `<u>${keyWord}</u>`);
        }
      }
    });
    
    // Add section instructions (if missing)
    const INSTRUCTIONS = {
      'COMP': 'Read the following passages carefully and answer the questions that follow.',
      'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
      'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
      'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
      'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
      'E': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
    };
    
    data.questions.forEach(q => {
      if (!q.sectionInstructions && q.section && INSTRUCTIONS[q.section]) {
        q.sectionInstructions = INSTRUCTIONS[q.section];
      }
      if (!q.correctAnswer || q.correctAnswer === '') {
        q.correctAnswer = 'A'; // Placeholder
      }
    });
    
    // Save processed file
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
    
    // Import directly
    console.log('   📤 Importing to Firestore...');
    execSync(`node import_bece_english.js --file=${filePath}`, { 
      encoding: 'utf8',
      stdio: 'pipe'
    });
    
    console.log(`   ✅ Successfully imported ${questionCount} questions`);
    successCount++;
    
  } catch (error) {
    console.error(`   ❌ Error: ${error.message.substring(0, 100)}`);
    failedYears.push(year);
  }
});

console.log('\n═══════════════════════════════════════════');
console.log('✅ Import Complete!');
console.log(`   Successfully imported: ${successCount} years`);
console.log(`   Failed: ${failedYears.length} years`);
if (failedYears.length > 0) {
  console.log(`   Failed years: ${failedYears.join(', ')}`);
}
