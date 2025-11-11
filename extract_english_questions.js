const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');

/**
 * Extract BECE English questions from DOCX files
 * 
 * BECE English typically has:
 * - Section A: Comprehension passages (Questions 1-15)
 * - Section B: Grammar/Vocabulary with instructions (Questions 16-40)
 * - Section C: Essay/Composition (Questions 41-50)
 * 
 * This script extracts the raw text and helps structure it into JSON
 */

async function extractQuestionsFromDocx(filePath, year) {
  try {
    console.log(`\n📖 Processing: ${filePath}`);
    
    // Extract text from DOCX
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    console.log(`✓ Extracted ${text.length} characters`);
    
    // Save raw text for manual review
    const outputDir = './extracted_english';
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    const txtPath = path.join(outputDir, `english_${year}_raw.txt`);
    fs.writeFileSync(txtPath, text, 'utf8');
    console.log(`✓ Saved raw text to: ${txtPath}`);
    
    // Try to identify sections and passages
    const sections = identifySections(text);
    const passages = extractPassages(text, year);
    const questions = extractQuestions(text, year);
    
    // Create structured JSON template
    const jsonStructure = {
      year: year,
      examType: 'bece',
      subject: 'english',
      metadata: {
        totalQuestions: questions.length,
        sections: sections,
        extractedAt: new Date().toISOString(),
        needsManualReview: true,
        notes: 'This is auto-extracted. Please review and complete missing fields.'
      },
      passages: passages,
      questions: questions
    };
    
    const jsonPath = path.join(outputDir, `english_${year}_template.json`);
    fs.writeFileSync(jsonPath, JSON.stringify(jsonStructure, null, 2), 'utf8');
    console.log(`✓ Saved JSON template to: ${jsonPath}`);
    console.log(`  - Found ${passages.length} passages`);
    console.log(`  - Found ${questions.length} question patterns`);
    
    return jsonStructure;
    
  } catch (error) {
    console.error(`❌ Error processing ${filePath}:`, error.message);
    return null;
  }
}

function identifySections(text) {
  const sections = [];
  
  // Look for common BECE section markers
  const sectionPatterns = [
    /SECTION\s+A/i,
    /SECTION\s+B/i,
    /SECTION\s+C/i,
    /Part\s+A/i,
    /Part\s+B/i,
    /Part\s+C/i,
  ];
  
  sectionPatterns.forEach(pattern => {
    const match = text.match(pattern);
    if (match) {
      sections.push({
        name: match[0],
        position: match.index
      });
    }
  });
  
  return sections;
}

function extractPassages(text, year) {
  const passages = [];
  
  // Common passage indicators
  const passageMarkers = [
    'Read the passage',
    'Read the following',
    'Study the passage',
    'The passage below',
  ];
  
  // Try to find passages (this is a heuristic approach)
  const lines = text.split('\n');
  let inPassage = false;
  let currentPassage = '';
  let passageCount = 0;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    
    // Check if this line starts a passage
    const isPassageStart = passageMarkers.some(marker => 
      line.toLowerCase().includes(marker.toLowerCase())
    );
    
    if (isPassageStart) {
      if (currentPassage) {
        // Save previous passage
        passageCount++;
        passages.push({
          id: `english_${year}_passage_${passageCount}`,
          title: `Passage ${passageCount}`,
          content: currentPassage.trim(),
          subject: 'english',
          examType: 'bece',
          year: year,
          section: 'A',
          questionRange: [], // To be filled manually
          createdBy: 'auto-extract',
          isActive: true
        });
      }
      inPassage = true;
      currentPassage = '';
      continue;
    }
    
    // Check if passage ends (usually at a question number)
    if (inPassage && /^\d+\./.test(line)) {
      // This looks like a question, end the passage
      if (currentPassage.length > 100) { // Only if we have substantial text
        passageCount++;
        passages.push({
          id: `english_${year}_passage_${passageCount}`,
          title: `Passage ${passageCount}`,
          content: currentPassage.trim(),
          subject: 'english',
          examType: 'bece',
          year: year,
          section: 'A',
          questionRange: [],
          createdBy: 'auto-extract',
          isActive: true
        });
      }
      inPassage = false;
      currentPassage = '';
    }
    
    if (inPassage) {
      currentPassage += line + ' ';
    }
  }
  
  return passages;
}

function extractQuestions(text, year) {
  const questions = [];
  
  // Match patterns like "1.", "2.", etc. followed by question text
  const questionPattern = /(\d+)\.\s+(.+?)(?=\n\d+\.|$)/gs;
  const matches = [...text.matchAll(questionPattern)];
  
  matches.forEach((match, index) => {
    const questionNumber = parseInt(match[1]);
    const questionText = match[2].trim();
    
    // Try to extract options (A, B, C, D)
    const optionPattern = /([A-D])\.\s+(.+?)(?=[A-D]\.|$)/g;
    const options = [...questionText.matchAll(optionPattern)];
    
    const questionObj = {
      id: `english_${year}_q${questionNumber}`,
      questionText: questionText.split(/[A-D]\./)[0].trim(),
      type: 'multipleChoice',
      subject: 'english',
      examType: 'bece',
      year: year,
      section: questionNumber <= 15 ? 'A' : questionNumber <= 40 ? 'B' : 'C',
      questionNumber: questionNumber,
      options: options.length === 4 ? options.map(opt => `${opt[1]}. ${opt[2].trim()}`) : [],
      correctAnswer: '', // To be filled from answer key
      marks: 1,
      difficulty: 'medium',
      topics: ['To be categorized'],
      createdBy: 'auto-extract',
      isActive: true,
      passageId: null, // To be linked manually
      sectionInstructions: null, // To be added manually
      relatedQuestions: null
    };
    
    questions.push(questionObj);
  });
  
  return questions;
}

async function extractAnswersFromPdf(pdfPath) {
  console.log(`\n📄 Processing answer key: ${pdfPath}`);
  console.log('⚠️  PDF extraction requires manual review');
  console.log('   Please extract answers manually and add to JSON files');
  
  // PDF extraction would require pdf-parse or similar library
  // For now, we'll note that answers need manual entry
  return null;
}

async function processAllEnglishFiles() {
  console.log('🚀 BECE English Question Extractor');
  console.log('═══════════════════════════════════════════\n');
  
  const assetsDir = './assets/bece English';
  const files = fs.readdirSync(assetsDir);
  
  // Filter for question files
  const questionFiles = files.filter(file => 
    file.includes('questions') && file.endsWith('.docx')
  );
  
  console.log(`Found ${questionFiles.length} question files to process\n`);
  
  let processed = 0;
  let failed = 0;
  
  for (const file of questionFiles) {
    // Extract year from filename
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) {
      console.log(`⚠️  Skipping ${file} - couldn't extract year`);
      continue;
    }
    
    const year = yearMatch[1];
    const filePath = path.join(assetsDir, file);
    
    const result = await extractQuestionsFromDocx(filePath, year);
    
    if (result) {
      processed++;
    } else {
      failed++;
    }
    
    // Small delay to avoid overwhelming the system
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  console.log('\n═══════════════════════════════════════════');
  console.log('✅ Extraction Complete!');
  console.log(`   Processed: ${processed} files`);
  console.log(`   Failed: ${failed} files`);
  console.log('\n📁 Output directory: ./extracted_english');
  console.log('\n⚠️  NEXT STEPS:');
  console.log('   1. Review raw text files in ./extracted_english');
  console.log('   2. Edit JSON templates to add:');
  console.log('      - Correct answers from answer key');
  console.log('      - Link questions to passages (passageId)');
  console.log('      - Add section instructions');
  console.log('      - Verify question text and options');
  console.log('   3. Run import script for each year');
  console.log('\n💡 TIP: Start with one year (e.g., 2022) to test the process');
}

// Check if mammoth is installed
try {
  require.resolve('mammoth');
} catch (e) {
  console.error('❌ Error: mammoth package not found');
  console.error('\n📦 Please install required packages:');
  console.error('   npm install mammoth');
  process.exit(1);
}

// Run the extraction
processAllEnglishFiles()
  .then(() => {
    console.log('\n✨ Script completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
