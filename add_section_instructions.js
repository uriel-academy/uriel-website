const fs = require('fs');

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

function addSectionInstructions(filePath) {
  console.log(`📖 Reading ${filePath}...`);
  
  // Read the JSON file
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  
  let updatedCount = 0;
  let sectionsFound = new Set();
  
  // Add sectionInstructions to each question
  data.questions.forEach(question => {
    const section = question.section;
    
    if (section && SECTION_INSTRUCTIONS[section]) {
      question.sectionInstructions = SECTION_INSTRUCTIONS[section];
      sectionsFound.add(section);
      updatedCount++;
    } else if (section) {
      console.warn(`⚠️  Unknown section: ${section} in question ${question.id}`);
    }
  });
  
  // Save the updated file
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
  
  console.log(`\n✅ Updated ${updatedCount} questions`);
  console.log(`📊 Sections found: ${Array.from(sectionsFound).sort().join(', ')}`);
  console.log(`💾 Saved to ${filePath}`);
}

// Get file path from command line argument
const filePath = process.argv[2];

if (!filePath) {
  console.error('❌ Usage: node add_section_instructions.js <json-file-path>');
  console.log('\nExample:');
  console.log('  node add_section_instructions.js ./english_2022_questions.json');
  process.exit(1);
}

if (!fs.existsSync(filePath)) {
  console.error(`❌ File not found: ${filePath}`);
  process.exit(1);
}

addSectionInstructions(filePath);
