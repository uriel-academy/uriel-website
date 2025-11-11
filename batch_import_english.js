const { execSync } = require('child_process');
const fs = require('fs');

/**
 * Batch import all English question files to Firestore
 */

const years = [];
for (let y = 1990; y <= 2018; y++) {
  years.push(y);
}

console.log('🚀 Batch Import English Questions to Firestore');
console.log('═════════════════════════════════════════════\n');
console.log(`Importing ${years.length} years...\n`);

let successCount = 0;
let skipCount = 0;
let totalQuestions = 0;

years.forEach(year => {
  const filePath = `./english_${year}_questions.json`;
  
  if (!fs.existsSync(filePath)) {
    console.log(`⏭️  Skipping ${year} - file not found`);
    skipCount++;
    return;
  }
  
  try {
    // Check question count
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const questionCount = data.questions.length;
    
    if (questionCount === 0) {
      console.log(`⏭️  Skipping ${year} - 0 questions`);
      skipCount++;
      return;
    }
    
    console.log(`\n📅 Year ${year} (${questionCount} questions):`);
    
    // Import
    const output = execSync(`node import_bece_english.js --file=${filePath}`, { 
      encoding: 'utf8',
      stdio: 'pipe'
    });
    
    console.log(`   ✅ Imported successfully`);
    successCount++;
    totalQuestions += questionCount;
    
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    skipCount++;
  }
});

console.log('\n═════════════════════════════════════════════');
console.log('✅ Batch Import Complete!');
console.log(`   Successfully imported: ${successCount} years`);
console.log(`   Total questions: ${totalQuestions}`);
console.log(`   Skipped/Failed: ${skipCount} years`);
console.log('\n⚠️  REMEMBER: All answers are placeholders (A)');
console.log('   Update from PDF answer keys before final use!');
