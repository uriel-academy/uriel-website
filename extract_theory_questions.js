const fs = require('fs').promises;
const path = require('path');
const mammoth = require('mammoth');

// Subject mapping for consistent naming
const SUBJECT_MAP = {
  'MATHEMATICS': 'Mathematics',
  'english': 'English',
  'SCIENCE': 'Integrated Science',
  'social studies': 'Social Studies',
  'RELIGIOUS AND MORAL EDUCATION': 'RME',
  'ict': 'ICT',
  'FRENCH': 'French',
  'CREATIVE ART AND DESIGN': 'Creative Arts',
  'CAREER TECHNOLOGY': 'Career Technology',
  'Asante Twi': 'Asante Twi',
  'GA': 'Ga'
};

// Parse question text to extract marks
function extractMarks(text) {
  // Common patterns: [5 marks], (10 marks), 5marks, etc.
  const marksMatch = text.match(/[\[\(]?(\d+)\s*marks?[\]\)]?/i);
  if (marksMatch) {
    return parseInt(marksMatch[1]);
  }
  // Default to 5 marks if not specified
  return 5;
}

// Parse question number from text
function extractQuestionNumber(text) {
  // Patterns: "1.", "Question 1:", "Q1.", etc.
  const qNumMatch = text.match(/^(?:Question\s+)?(\d+)[.\):\s]/i);
  if (qNumMatch) {
    return parseInt(qNumMatch[1]);
  }
  return null;
}

// Split text into individual questions
function parseQuestions(text, subject, year) {
  const questions = [];
  
  // Split by common question delimiters
  // Look for patterns like "1.", "2.", "Question 1", etc at start of line
  const questionRegex = /(?:^|\n)(?:Question\s+)?(\d+)[.\):\s]/gi;
  
  const matches = [...text.matchAll(questionRegex)];
  
  if (matches.length === 0) {
    // No clear question numbers, treat entire text as one question
    console.warn(`⚠️  ${subject} ${year}: No question numbers found, treating as single question`);
    return [{
      questionNumber: 1,
      questionText: text.trim(),
      marks: extractMarks(text),
      subject,
      year,
      examType: 'BECE',
      type: 'theory'
    }];
  }
  
  // Extract each question
  for (let i = 0; i < matches.length; i++) {
    const match = matches[i];
    const questionNum = parseInt(match[1]);
    const startIndex = match.index + match[0].length;
    const endIndex = i < matches.length - 1 ? matches[i + 1].index : text.length;
    
    const questionText = text.substring(startIndex, endIndex).trim();
    
    if (questionText.length > 10) { // Skip empty/invalid questions
      questions.push({
        id: `theory_${subject.toLowerCase().replace(/\s+/g, '_')}_${year}_q${questionNum}`,
        questionNumber: questionNum,
        questionText,
        marks: extractMarks(questionText),
        subject,
        year,
        examType: 'BECE',
        type: 'theory',
        difficulty: 'medium', // Default difficulty
        topics: [] // Can be filled later
      });
    }
  }
  
  return questions;
}

// Process a single DOCX file
async function processDocxFile(filePath, subject, year) {
  try {
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    if (!text || text.trim().length < 50) {
      console.warn(`⚠️  ${subject} ${year}: Empty or too short, skipping`);
      return [];
    }
    
    const questions = parseQuestions(text, subject, year);
    console.log(`✅ ${subject} ${year}: Extracted ${questions.length} questions`);
    
    return questions;
  } catch (error) {
    console.error(`❌ Error processing ${filePath}:`, error.message);
    return [];
  }
}

// Process all files for a subject
async function processSubject(subjectFolder) {
  const folderName = path.basename(subjectFolder);
  
  // Extract subject name from folder name
  // e.g., "bece MATHEMATICS  theory questions" -> "Mathematics"
  const subjectMatch = folderName.match(/bece\s+(.+?)\s+theory questions/i);
  if (!subjectMatch) {
    console.warn(`⚠️  Skipping invalid folder: ${folderName}`);
    return { subject: null, questions: [] };
  }
  
  const rawSubject = subjectMatch[1].trim();
  const subject = SUBJECT_MAP[rawSubject] || rawSubject;
  
  console.log(`\n📚 Processing ${subject}...`);
  
  const files = await fs.readdir(subjectFolder);
  const docxFiles = files.filter(f => f.endsWith('.docx') && !f.startsWith('~$'));
  
  const allQuestions = [];
  
  for (const file of docxFiles) {
    // Extract year from filename
    const yearMatch = file.match(/(\d{4})/);
    if (!yearMatch) {
      console.warn(`⚠️  Skipping file without year: ${file}`);
      continue;
    }
    
    const year = parseInt(yearMatch[1]);
    const filePath = path.join(subjectFolder, file);
    
    const questions = await processDocxFile(filePath, subject, year);
    allQuestions.push(...questions);
  }
  
  return { subject, questions: allQuestions };
}

// Main execution
async function main() {
  const theoryFolder = path.join(__dirname, 'assets', 'bece theory');
  
  console.log('🚀 Starting BECE Theory Questions Extraction...\n');
  console.log(`📂 Source folder: ${theoryFolder}\n`);
  
  try {
    const subjectFolders = await fs.readdir(theoryFolder);
    
    const allSubjects = [];
    const summary = {
      totalSubjects: 0,
      totalQuestions: 0,
      bySubject: {}
    };
    
    for (const folder of subjectFolders) {
      const folderPath = path.join(theoryFolder, folder);
      const stat = await fs.stat(folderPath);
      
      if (!stat.isDirectory()) continue;
      
      const { subject, questions } = await processSubject(folderPath);
      
      if (subject && questions.length > 0) {
        allSubjects.push({ subject, questions });
        
        summary.totalSubjects++;
        summary.totalQuestions += questions.length;
        summary.bySubject[subject] = questions.length;
        
        // Save individual subject JSON
        const outputFile = path.join(__dirname, `bece_theory_${subject.toLowerCase().replace(/\s+/g, '_')}.json`);
        await fs.writeFile(outputFile, JSON.stringify(questions, null, 2));
        console.log(`💾 Saved ${questions.length} questions to ${path.basename(outputFile)}`);
      }
    }
    
    // Save combined JSON
    const combinedFile = path.join(__dirname, 'bece_theory_all.json');
    await fs.writeFile(combinedFile, JSON.stringify(allSubjects, null, 2));
    
    // Save summary
    const summaryFile = path.join(__dirname, 'bece_theory_summary.json');
    await fs.writeFile(summaryFile, JSON.stringify(summary, null, 2));
    
    console.log('\n' + '='.repeat(50));
    console.log('✨ EXTRACTION COMPLETE!');
    console.log('='.repeat(50));
    console.log(`📊 Total Subjects: ${summary.totalSubjects}`);
    console.log(`📝 Total Questions: ${summary.totalQuestions}`);
    console.log('\n📋 Breakdown by Subject:');
    Object.entries(summary.bySubject).forEach(([subj, count]) => {
      console.log(`   ${subj}: ${count} questions`);
    });
    console.log('\n💾 Output files:');
    console.log(`   - bece_theory_all.json (combined)`);
    console.log(`   - bece_theory_summary.json (statistics)`);
    console.log(`   - bece_theory_[subject].json (individual subjects)`);
    console.log('\n✅ Ready for Firebase import!');
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

// Run the script
main();
