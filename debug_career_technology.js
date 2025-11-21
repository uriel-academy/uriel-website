const mammoth = require('mammoth');
const fs = require('fs').promises;
const path = require('path');

async function debugDocxContent() {
  console.log('🔍 Debugging Career Technology DOCX content...\n');

  const subjectFolder = 'assets/bece Career Technology';

  try {
    const files = await fs.readdir(subjectFolder);
    const questionFiles = files.filter(f =>
      f.includes('questions') && f.endsWith('.docx') && !f.includes('~$')
    );

    console.log(`Found question files: ${questionFiles.join(', ')}\n`);

    // Process first file
    const file = questionFiles[0];
    const filePath = path.join(subjectFolder, file);
    const yearMatch = file.match(/(\d{4})/);
    const year = yearMatch ? yearMatch[1] : 'unknown';

    console.log(`Reading ${file} (${year})...`);

    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;

    console.log('=== RAW TEXT (first 2000 characters) ===');
    console.log(text.substring(0, 2000));
    console.log('\n=== END RAW TEXT ===\n');

    // Check for patterns
    const aMatches = text.match(/A\.\s\s/g) || [];
    const eMatches = text.match(/E\.\s\s/g) || [];
    const numberMatches = text.match(/\d+\.\s/g) || [];

    console.log(`Found ${aMatches.length} "A.  " patterns`);
    console.log(`Found ${eMatches.length} "E.  " patterns`);
    console.log(`Found ${numberMatches.length} number patterns`);

    // Show first few number patterns
    console.log('\nFirst 10 number patterns:');
    numberMatches.slice(0, 10).forEach((match, i) => {
      const index = text.indexOf(match);
      const context = text.substring(Math.max(0, index - 20), index + 50);
      console.log(`${i + 1}. "${match.trim()}" at position ${index}: "${context.replace(/\n/g, '\\n')}"`);
    });

  } catch (error) {
    console.error('Error debugging:', error);
  }
}

debugDocxContent();