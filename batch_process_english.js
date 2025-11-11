const fs = require('fs');
const { execSync } = require('child_process');

/**
 * Batch process all English JSON files:
 * 1. Add underline markers
 * 2. Add section instructions
 * 3. Add placeholder answers
 */

const years = [];
for (let y = 1990; y <= 2018; y++) {
  years.push(y);
}

console.log('🚀 Batch Processing English Questions');
console.log('════════════════════════════════════════\n');
console.log(`Processing ${years.length} years...\n`);

let successCount = 0;
let skipCount = 0;

years.forEach(year => {
  const filePath = `./english_${year}_questions.json`;
  
  if (!fs.existsSync(filePath)) {
    console.log(`⏭️  Skipping ${year} - file not found`);
    skipCount++;
    return;
  }
  
  console.log(`\n📅 Year ${year}:`);
  
  try {
    // Step 1: Add underline markers
    console.log('   🔤 Adding underline markers...');
    execSync(`node add_underline_markers.js ${filePath}`, { stdio: 'pipe' });
    console.log('   ✅ Underlines added');
    
    // Step 2: Add section instructions
    console.log('   📋 Adding section instructions...');
    execSync(`node add_section_instructions.js ${filePath}`, { stdio: 'pipe' });
    console.log('   ✅ Instructions added');
    
    // Step 3: Add placeholder answers
    console.log('   🎯 Adding placeholder answers...');
    execSync(`node add_placeholder_answers.js ${filePath}`, { stdio: 'pipe' });
    console.log('   ✅ Placeholders added');
    
    successCount++;
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    skipCount++;
  }
});

console.log('\n════════════════════════════════════════');
console.log('✅ Batch Processing Complete!');
console.log(`   Successfully processed: ${successCount} years`);
console.log(`   Skipped/Failed: ${skipCount} years`);
console.log('\n📝 Next Steps:');
console.log('   1. Review the JSON files');
console.log('   2. Import all: node batch_import_english.js');
console.log('   3. Update answers from PDF keys');
