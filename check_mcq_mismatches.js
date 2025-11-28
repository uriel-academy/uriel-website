const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMCQMismatches() {
  console.log('🔍 Checking for MCQ answer mismatches...\n');
  
  const questionsRef = db.collection('questions');
  const snapshot = await questionsRef
    .where('type', '==', 'multipleChoice')
    .get();
  
  console.log(`📊 Total MCQ questions: ${snapshot.size}\n`);
  
  const issues = [];
  let checkedCount = 0;
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    checkedCount++;
    
    if (checkedCount % 100 === 0) {
      console.log(`   Checked ${checkedCount}/${snapshot.size}...`);
    }
    
    // Check if question has options
    if (!data.options || !Array.isArray(data.options) || data.options.length === 0) {
      issues.push({
        id: doc.id,
        type: 'NO_OPTIONS',
        subject: data.subject,
        year: data.year,
        questionText: data.questionText?.substring(0, 80) + '...',
      });
      continue;
    }
    
    // Check if correctAnswer exists
    if (!data.correctAnswer) {
      issues.push({
        id: doc.id,
        type: 'NO_CORRECT_ANSWER',
        subject: data.subject,
        year: data.year,
        questionText: data.questionText?.substring(0, 80) + '...',
        options: data.options,
      });
      continue;
    }
    
    // Extract letter from correctAnswer
    let correctLetter = data.correctAnswer.trim();
    if (correctLetter.includes('.')) {
      correctLetter = correctLetter.split('.')[0].trim();
    }
    correctLetter = correctLetter.toUpperCase();
    
    // Check if the correct answer letter maps to an existing option
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    const letterIndex = letters.indexOf(correctLetter);
    
    if (letterIndex === -1) {
      issues.push({
        id: doc.id,
        type: 'INVALID_LETTER',
        subject: data.subject,
        year: data.year,
        correctAnswer: data.correctAnswer,
        questionText: data.questionText?.substring(0, 80) + '...',
      });
      continue;
    }
    
    if (letterIndex >= data.options.length) {
      issues.push({
        id: doc.id,
        type: 'LETTER_OUT_OF_RANGE',
        subject: data.subject,
        year: data.year,
        correctAnswer: data.correctAnswer,
        correctLetter: correctLetter,
        optionsCount: data.options.length,
        questionText: data.questionText?.substring(0, 80) + '...',
        options: data.options,
      });
      continue;
    }
    
    // Check if options are properly formatted (should start with letter)
    const optionAtIndex = data.options[letterIndex];
    if (!optionAtIndex.toUpperCase().startsWith(correctLetter)) {
      issues.push({
        id: doc.id,
        type: 'OPTION_FORMAT_MISMATCH',
        subject: data.subject,
        year: data.year,
        correctAnswer: data.correctAnswer,
        correctLetter: correctLetter,
        expectedOption: optionAtIndex,
        questionText: data.questionText?.substring(0, 80) + '...',
        options: data.options,
      });
    }
  }
  
  console.log(`\n✅ Finished checking ${checkedCount} questions\n`);
  
  if (issues.length === 0) {
    console.log('🎉 No issues found! All MCQ questions are properly mapped.\n');
  } else {
    console.log(`⚠️  Found ${issues.length} issues:\n`);
    
    // Group by issue type
    const grouped = {};
    issues.forEach(issue => {
      if (!grouped[issue.type]) grouped[issue.type] = [];
      grouped[issue.type].push(issue);
    });
    
    for (const [type, items] of Object.entries(grouped)) {
      console.log(`\n📌 ${type}: ${items.length} issues`);
      console.log('─'.repeat(80));
      
      items.slice(0, 5).forEach((issue, idx) => {
        console.log(`\n${idx + 1}. Document ID: ${issue.id}`);
        console.log(`   Subject: ${issue.subject}, Year: ${issue.year}`);
        console.log(`   Question: ${issue.questionText}`);
        
        if (issue.correctAnswer) {
          console.log(`   Correct Answer: ${issue.correctAnswer}`);
        }
        if (issue.correctLetter) {
          console.log(`   Extracted Letter: ${issue.correctLetter}`);
        }
        if (issue.optionsCount) {
          console.log(`   Options Count: ${issue.optionsCount}`);
        }
        if (issue.options) {
          console.log(`   Options:`);
          issue.options.forEach((opt, i) => console.log(`      ${i}: ${opt}`));
        }
      });
      
      if (items.length > 5) {
        console.log(`\n   ... and ${items.length - 5} more`);
      }
    }
    
    // Export full report
    const fs = require('fs');
    fs.writeFileSync(
      'mcq_mismatch_report.json',
      JSON.stringify(issues, null, 2)
    );
    console.log(`\n📄 Full report saved to mcq_mismatch_report.json`);
  }
  
  process.exit(0);
}

checkMCQMismatches().catch(console.error);
