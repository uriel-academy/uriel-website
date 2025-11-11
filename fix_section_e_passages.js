const fs = require('fs');

/**
 * Extract Section E cloze passages and link them to questions
 * Section E format: A passage with gaps marked as ---31---, ---32---, etc.
 */

function extractSectionEPassage(rawText, year) {
  // Find Section E
  const sectionEStart = rawText.indexOf('SECTION E');
  if (sectionEStart === -1) {
    console.log(`⚠️ No Section E found in ${year}`);
    return null;
  }
  
  // Find where Section E ends (next section or PART B)
  let sectionEEnd = rawText.indexOf('PART B', sectionEStart);
  if (sectionEEnd === -1) {
    sectionEEnd = rawText.indexOf('SECTION F', sectionEStart);
  }
  if (sectionEEnd === -1) {
    sectionEEnd = rawText.length;
  }
  
  const sectionEText = rawText.substring(sectionEStart, sectionEEnd);
  
  // Extract the instruction (first paragraph after SECTION E)
  const instructionMatch = sectionEText.match(/SECTION E\s+(.*?)(?=The |In |[A-Z][a-z]+ [a-z]+)/s);
  const instruction = instructionMatch ? instructionMatch[1].trim() : '';
  
  // Find the passage text (contains ---XX--- markers)
  const passageMatch = sectionEText.match(/(.*?---3\d---.*?)(?=\n\n*3\d\.|\n\s*Choose from)/s);
  if (!passageMatch) {
    console.log(`⚠️ No cloze passage found in Section E for ${year}`);
    return null;
  }
  
  let passageText = passageMatch[1].trim();
  
  // Clean up the passage
  passageText = passageText
    .replace(/SECTION E.*?\n/i, '')
    .replace(/In the following passage.*?\n/i, '')
    .replace(/Against each number.*?\n/gi, '')
    .trim();
  
  // Determine which questions this passage covers by finding gap numbers
  const gapNumbers = [];
  const gapMatches = passageText.matchAll(/---(\d+)---/g);
  for (const match of gapMatches) {
    gapNumbers.push(parseInt(match[1]));
  }
  
  if (gapNumbers.length === 0) {
    console.log(`⚠️ No gap numbers found in Section E passage for ${year}`);
    return null;
  }
  
  const minQ = Math.min(...gapNumbers);
  const maxQ = Math.max(...gapNumbers);
  
  console.log(`✅ Found Section E passage for ${year}`);
  console.log(`   Questions: ${minQ}-${maxQ}`);
  console.log(`   Gaps found: ${gapNumbers.length}`);
  
  const passage = {
    id: `english_${year}_passage_section_e`,
    title: 'SECTION E - Cloze Test',
    content: passageText,
    subject: 'english',
    examType: 'bece',
    year: year.toString(),
    section: 'E',
    questionRange: Array.from({ length: maxQ - minQ + 1 }, (_, i) => minQ + i),
    createdBy: 'admin',
    isActive: true
  };
  
  return {
    passage,
    questionNumbers: gapNumbers
  };
}

function fixSectionEPassages(year) {
  const jsonPath = `./english_${year}_questions.json`;
  const rawPath = `./extracted_english/english_${year}_raw.txt`;
  
  if (!fs.existsSync(jsonPath)) {
    console.log(`❌ JSON file not found: ${jsonPath}`);
    return;
  }
  
  if (!fs.existsSync(rawPath)) {
    console.log(`❌ Raw text file not found: ${rawPath}`);
    return;
  }
  
  console.log(`\n🔧 Fixing Section E passages for ${year}...`);
  
  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const rawText = fs.readFileSync(rawPath, 'utf8');
  
  const result = extractSectionEPassage(rawText, year);
  
  if (!result) {
    console.log(`⚠️ No Section E passage to add for ${year}`);
    return;
  }
  
  const { passage, questionNumbers } = result;
  
  // Add passage to data
  if (!data.passages) {
    data.passages = [];
  }
  data.passages.push(passage);
  
  // Link questions to passage
  let linkedCount = 0;
  for (const qNum of questionNumbers) {
    const question = data.questions.find(q => q.questionNumber === qNum);
    if (question) {
      question.passageId = passage.id;
      // Set question text to just the gap instruction if empty
      if (!question.questionText || question.questionText.trim() === '') {
        question.questionText = `Choose the word that best fills gap ${qNum}`;
      }
      linkedCount++;
    }
  }
  
  // Save updated data
  fs.writeFileSync(jsonPath, JSON.stringify(data, null, 2));
  
  console.log(`✅ Fixed Section E for ${year}`);
  console.log(`   Added 1 passage`);
  console.log(`   Linked ${linkedCount} questions`);
}

// Run for specified years
if (require.main === module) {
  const years = process.argv.slice(2);
  
  if (years.length === 0) {
    console.log('Usage: node fix_section_e_passages.js <year1> <year2> ...');
    console.log('Example: node fix_section_e_passages.js 2024 2025');
    process.exit(1);
  }
  
  for (const year of years) {
    fixSectionEPassages(parseInt(year));
  }
  
  console.log('\n✅ All done!');
}

module.exports = { fixSectionEPassages, extractSectionEPassage };
