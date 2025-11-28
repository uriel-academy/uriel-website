// Comprehensive answer validation using database queries
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const fs = require('fs');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Load answer keys
const mathAnswers = JSON.parse(fs.readFileSync('mathematics_answers.json', 'utf8'));
const rmeAnswers = JSON.parse(fs.readFileSync('bece_1999_answers.json', 'utf8'));

// Extract letter from "A. text" format or just "A"
function extractLetter(answerString) {
  if (!answerString) return null;
  
  // If already just a single letter, return it
  if (/^[A-E]$/.test(answerString.trim())) {
    return answerString.trim();
  }
  
  // Otherwise extract from "A. text" format
  const match = answerString.match(/^([A-E])\./);
  return match ? match[1] : null;
}

const results = {
  totalChecked: 0,
  matchCount: 0,
  mismatches: []
};

async function validateMathematics() {
  console.log('📐 Validating Mathematics (1990-2025)...\n');
  
  for (const [year, answers] of Object.entries(mathAnswers)) {
    process.stdout.write(`  Checking ${year}... `);
    
    // Query all MCQ questions for this year (year is stored as string, filter out theory)
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .where('year', '==', year)
      .where('type', '==', 'multipleChoice')
      .get();
    
    if (snapshot.empty) {
      console.log(`⚠️  No questions found`);
      continue;
    }
    
    let yearMismatches = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const qNum = data.questionNumber;
      const dbAnswer = extractLetter(data.correctAnswer);
      const keyAnswer = answers[qNum.toString()];
      
      results.totalChecked++;
      
      if (dbAnswer === keyAnswer) {
        results.matchCount++;
      } else {
        yearMismatches++;
        results.mismatches.push({
          docId: doc.id,
          subject: 'Mathematics',
          year: year,
          questionNumber: qNum,
          expected: keyAnswer,
          got: dbAnswer,
          questionText: data.questionText ? data.questionText.substring(0, 100) : 'N/A',
          options: data.options || []
        });
      }
    }
    
    if (yearMismatches > 0) {
      console.log(`❌ ${yearMismatches} mismatches`);
    } else {
      console.log(`✅ All match (${snapshot.size})`);
    }
  }
}

async function validateRME() {
  console.log('\n📿 Validating RME 1999...\n');
  
  // Query all RME 1999 MCQ questions (year is string)
  const snapshot = await db.collection('questions')
    .where('subject', '==', 'rme')
    .where('year', '==', '1999')
    .where('type', '==', 'multipleChoice')
    .get();
  
  if (snapshot.empty) {
    console.log('  ⚠️  No questions found');
    return;
  }
  
  let mismatches = 0;
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const qNum = data.questionNumber;
    const dbAnswer = extractLetter(data.correctAnswer);
    const keyAnswer = rmeAnswers[`q${qNum}`];
    
    results.totalChecked++;
    
    if (dbAnswer === keyAnswer) {
      results.matchCount++;
    } else {
      mismatches++;
      results.mismatches.push({
        docId: doc.id,
        subject: 'RME',
        year: 1999,
        questionNumber: qNum,
        expected: keyAnswer,
        got: dbAnswer,
        questionText: data.questionText ? data.questionText.substring(0, 100) : 'N/A',
        options: data.options || []
      });
    }
  }
  
  if (mismatches > 0) {
    console.log(`  ❌ ${mismatches} mismatches out of ${snapshot.size}`);
  } else {
    console.log(`  ✅ All ${snapshot.size} questions match!`);
  }
}

async function validateICT() {
  console.log('\n💻 Validating ICT (2023-2025)...\n');
  
  for (const year of [2023, 2024, 2025]) {
    const filePath = `assets/bece_ict/ict_${year}_answers.json`;
    
    if (!fs.existsSync(filePath)) {
      console.log(`  ${year}: ⚠️  Answer key file not found`);
      continue;
    }
    
    const answers = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    
    // ICT answers are nested under 'multiple_choice' key
    const mcqAnswers = answers.multiple_choice || answers;
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ict')
      .where('year', '==', year.toString())
      .where('type', '==', 'multipleChoice')
      .get();
    
    if (snapshot.empty) {
      console.log(`  ${year}: ⚠️  No questions found in database`);
      continue;
    }
    
    let mismatches = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const qNum = data.questionNumber;
      const dbAnswer = extractLetter(data.correctAnswer);
      const keyAnswer = extractLetter(mcqAnswers[qNum.toString()] || mcqAnswers[`q${qNum}`]);
      
      results.totalChecked++;
      
      if (dbAnswer === keyAnswer) {
        results.matchCount++;
      } else {
        mismatches++;
        results.mismatches.push({
          docId: doc.id,
          subject: 'ICT',
          year: year,
          questionNumber: qNum,
          expected: keyAnswer,
          got: dbAnswer,
          questionText: data.questionText ? data.questionText.substring(0, 100) : 'N/A',
          options: data.options || []
        });
      }
    }
    
    if (mismatches > 0) {
      console.log(`  ${year}: ❌ ${mismatches} mismatches`);
    } else {
      console.log(`  ${year}: ✅ All ${snapshot.size} match`);
    }
  }
}

async function main() {
  console.log('🔍 COMPREHENSIVE ANSWER KEY VALIDATION\n');
  console.log('=' .repeat(80) + '\n');
  
  try {
    await validateMathematics();
    await validateRME();
    await validateICT();
    
    console.log('\n' + '='.repeat(80));
    console.log('📊 VALIDATION SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total Questions Checked: ${results.totalChecked}`);
    console.log(`✅ Correct Matches: ${results.matchCount} (${((results.matchCount/results.totalChecked)*100).toFixed(2)}%)`);
    console.log(`❌ Mismatches Found: ${results.mismatches.length} (${((results.mismatches.length/results.totalChecked)*100).toFixed(2)}%)`);
    console.log('='.repeat(80) + '\n');
    
    if (results.mismatches.length > 0) {
      console.log('⚠️  CRITICAL: Found answer mismatches!\n');
      
      // Group by subject
      const bySubject = {};
      results.mismatches.forEach(m => {
        if (!bySubject[m.subject]) bySubject[m.subject] = [];
        bySubject[m.subject].push(m);
      });
      
      for (const [subject, mismatches] of Object.entries(bySubject)) {
        console.log(`📌 ${subject}: ${mismatches.length} mismatches`);
        console.log('─'.repeat(80));
        
        mismatches.slice(0, 10).forEach((m, i) => {
          console.log(`\n${i + 1}. ${m.year} Q${m.questionNumber} (${m.docId})`);
          console.log(`   Expected: ${m.expected}`);
          console.log(`   Database: ${m.got}`);
          console.log(`   Question: ${m.questionText}`);
          if (m.options.length > 0) {
            console.log(`   Options:`);
            m.options.forEach((opt, idx) => {
              console.log(`      ${idx}: ${opt}`);
            });
          }
        });
        
        if (mismatches.length > 10) {
          console.log(`\n   ... and ${mismatches.length - 10} more`);
        }
        console.log('');
      }
      
      // Save full report
      fs.writeFileSync(
        'answer_validation_comprehensive_report.json',
        JSON.stringify(results, null, 2)
      );
      console.log('📄 Full report saved to answer_validation_comprehensive_report.json\n');
    } else {
      console.log('✅ SUCCESS: All answers match official answer keys!\n');
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit();
}

main();
