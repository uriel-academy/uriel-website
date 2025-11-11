const fs = require('fs');
const path = require('path');

/**
 * Extract section instructions from raw text files
 * This helps identify all unique section instructions across all years
 */

function extractSectionInstructions(year) {
  const rawPath = `./extracted_english/english_${year}_raw.txt`;
  
  if (!fs.existsSync(rawPath)) {
    return null;
  }
  
  const rawText = fs.readFileSync(rawPath, 'utf8');
  const lines = rawText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const sectionInstructions = {};
  let currentSection = null;
  let collectingInstruction = false;
  let instructionLines = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Detect section header (e.g., "SECTION A", "SECTION B")
    if (/^SECTION\s+([A-Z])$/i.test(line)) {
      // Save previous section instruction if exists
      if (currentSection && instructionLines.length > 0) {
        sectionInstructions[currentSection] = instructionLines.join(' ').trim();
      }
      
      const match = line.match(/^SECTION\s+([A-Z])$/i);
      currentSection = match[1].toUpperCase();
      instructionLines = [];
      collectingInstruction = true;
      continue;
    }
    
    // If we're collecting instructions and hit a question number, stop
    if (collectingInstruction && /^\d+\.$/.test(line)) {
      if (currentSection && instructionLines.length > 0) {
        sectionInstructions[currentSection] = instructionLines.join(' ').trim();
      }
      collectingInstruction = false;
      instructionLines = [];
      continue;
    }
    
    // Collect instruction lines (between section header and first question)
    if (collectingInstruction && line.length > 20) { // Likely an instruction, not just a number
      instructionLines.push(line);
    }
  }
  
  // Save last section if exists
  if (currentSection && instructionLines.length > 0) {
    sectionInstructions[currentSection] = instructionLines.join(' ').trim();
  }
  
  return sectionInstructions;
}

// Process specific years or all
const years = process.argv.slice(2);

if (years.length === 0) {
  console.log('📚 Section Instructions Extractor');
  console.log('════════════════════════════════════\n');
  console.log('Usage: node extract_section_instructions.js [years...]');
  console.log('\nExamples:');
  console.log('  node extract_section_instructions.js 2022');
  console.log('  node extract_section_instructions.js 2022 2023 2024');
  console.log('  node extract_section_instructions.js all');
  console.log('\n💡 This helps identify all unique section instructions');
  process.exit(0);
}

let yearsToProcess = [];

if (years[0] === 'all') {
  // Process all years from 1990-2025
  for (let y = 1990; y <= 2025; y++) {
    if (y !== 2021) yearsToProcess.push(y.toString());
  }
} else {
  yearsToProcess = years;
}

console.log('📚 Section Instructions Extractor');
console.log('════════════════════════════════════\n');

const allSectionInstructions = {};

yearsToProcess.forEach(year => {
  const instructions = extractSectionInstructions(year);
  
  if (!instructions) {
    console.log(`⚠️  ${year}: No raw file found`);
    return;
  }
  
  const sections = Object.keys(instructions).sort();
  
  if (sections.length === 0) {
    console.log(`⚠️  ${year}: No sections found`);
    return;
  }
  
  console.log(`\n📅 Year ${year}:`);
  sections.forEach(section => {
    console.log(`   ${section}: ${instructions[section].substring(0, 80)}...`);
    
    // Collect unique instructions
    if (!allSectionInstructions[section]) {
      allSectionInstructions[section] = new Set();
    }
    allSectionInstructions[section].add(instructions[section]);
  });
});

console.log('\n\n════════════════════════════════════');
console.log('📋 UNIQUE SECTION INSTRUCTIONS');
console.log('════════════════════════════════════\n');

const allSections = Object.keys(allSectionInstructions).sort();

allSections.forEach(section => {
  const instructions = Array.from(allSectionInstructions[section]);
  console.log(`\nSECTION ${section} (${instructions.length} variation${instructions.length > 1 ? 's' : ''}):`);
  instructions.forEach((instruction, idx) => {
    console.log(`\n  [${idx + 1}] ${instruction}`);
  });
});

console.log('\n\n════════════════════════════════════');
console.log('💻 JAVASCRIPT OBJECT FOR SCRIPTS:');
console.log('════════════════════════════════════\n');

console.log('const SECTION_INSTRUCTIONS = {');
allSections.forEach(section => {
  const instructions = Array.from(allSectionInstructions[section]);
  // Use the first (or most common) instruction as default
  const defaultInstruction = instructions[0];
  console.log(`  '${section}': '${defaultInstruction}',`);
});
console.log('};');

console.log('\n✅ Extraction complete!');
console.log(`   Total sections found: ${allSections.length}`);
console.log('   Copy the object above to update your scripts\n');
