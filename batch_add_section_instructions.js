const fs = require('fs');
const path = require('path');

// Define section instructions for BECE English
// Note: Section instructions are extracted from the original DOCX files
// Add more sections as needed (E, F, etc.)
const SECTION_INSTRUCTIONS = {
  'A': 'From the alternatives lettered A to D, choose the one which most suitably completes each sentence.',
  'B': 'Choose from the alternatives lettered A to D the one which is nearest in meaning to the underlined word in each sentence.',
  'C': 'In each of the following sentences a group of words has been underlined. Choose from the alternatives lettered A to D the one that best explains the underlined group of words.',
  'D': 'From the list of words lettered A to D, choose the one that is most nearly opposite in meaning to the word underlined in each sentence.',
  'E': 'Read the passage carefully and answer the questions that follow.',
  'F': 'Choose the option that best completes each sentence.',
  // Add more sections as discovered in other years
};

function addSectionInstructionsToFile(filePath) {
  console.log(`\n📖 Processing ${path.basename(filePath)}...`);
  
  // Read the JSON file
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  
  let updatedCount = 0;
  let skippedCount = 0;
  let sectionsFound = new Set();
  
  // Add sectionInstructions to each question
  data.questions.forEach(question => {
    const section = question.section;
    
    if (section && SECTION_INSTRUCTIONS[section]) {
      // Only update if not already present
      if (!question.sectionInstructions) {
        question.sectionInstructions = SECTION_INSTRUCTIONS[section];
        updatedCount++;
      } else {
        skippedCount++;
      }
      sectionsFound.add(section);
    } else if (section) {
      console.warn(`   ⚠️  Unknown section: ${section} in question ${question.id}`);
    }
  });
  
  // Save the updated file
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
  
  console.log(`   ✅ Updated: ${updatedCount} questions`);
  console.log(`   ⏭️  Skipped: ${skippedCount} questions (already had instructions)`);
  console.log(`   📊 Sections: ${Array.from(sectionsFound).sort().join(', ')}`);
  
  return { updated: updatedCount, skipped: skippedCount };
}

// Get all english_*_questions.json files in the current directory
const files = fs.readdirSync('.')
  .filter(f => f.startsWith('english_') && f.endsWith('_questions.json'))
  .sort();

if (files.length === 0) {
  console.log('❌ No english_*_questions.json files found in current directory');
  process.exit(1);
}

console.log('📚 Batch Add Section Instructions');
console.log('════════════════════════════════════');
console.log(`Found ${files.length} files to process\n`);

let totalUpdated = 0;
let totalSkipped = 0;

files.forEach(file => {
  try {
    const { updated, skipped } = addSectionInstructionsToFile(file);
    totalUpdated += updated;
    totalSkipped += skipped;
  } catch (error) {
    console.error(`   ❌ Error processing ${file}:`, error.message);
  }
});

console.log('\n════════════════════════════════════');
console.log('✅ Batch Processing Complete!');
console.log(`   Total updated: ${totalUpdated} questions`);
console.log(`   Total skipped: ${totalSkipped} questions`);
console.log(`   Files processed: ${files.length}`);
console.log('\n💡 Next: Re-import the updated files to Firebase');
console.log('   node import_bece_english.js --file=./english_YEAR_questions.json');
