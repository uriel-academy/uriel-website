const admin = require('firebase-admin');
const fs = require('fs');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Load answer keys
const mathematicsAnswers = JSON.parse(fs.readFileSync('./mathematics_answers.json', 'utf8'));
const rme1999Answers = JSON.parse(fs.readFileSync('./bece_1999_answers.json', 'utf8'));

// ICT answers from assets
const ict2023 = JSON.parse(fs.readFileSync('./assets/bece_ict/ict_2023_answers.json', 'utf8'));
const ict2024 = JSON.parse(fs.readFileSync('./assets/bece_ict/ict_2024_answers.json', 'utf8'));
const ict2025 = JSON.parse(fs.readFileSync('./assets/bece_ict/ict_2025_answers.json', 'utf8'));

// Ghanaian Languages answers
const ga2022 = JSON.parse(fs.readFileSync('./assets/ghanaian language/ga_2022_answers.json', 'utf8'));
const ga2023 = JSON.parse(fs.readFileSync('./assets/ghanaian language/ga_2023_answers.json', 'utf8'));
const ga2024 = JSON.parse(fs.readFileSync('./assets/ghanaian language/ga_2024_answers.json', 'utf8'));
const twi2023 = JSON.parse(fs.readFileSync('./assets/ghanaian language/asante_twi_2023_answers.json', 'utf8'));
const twi2024 = JSON.parse(fs.readFileSync('./assets/ghanaian language/asante_twi_2024_answers.json', 'utf8'));

async function validateAnswers() {
  console.log('🔍 Validating answer keys against database...\n');
  
  const mismatches = [];
  let totalChecked = 0;
  let matchCount = 0;
  
  // ====== VALIDATE MATHEMATICS ======
  console.log('📐 Checking Mathematics...');
  for (const [year, answers] of Object.entries(mathematicsAnswers)) {
    console.log(`  Checking ${year}...`);
    
    for (const [questionNum, correctAnswer] of Object.entries(answers)) {
      const docId = `mathematics_${year}_q${questionNum}`;
      const doc = await db.collection('questions').doc(docId).get();
      
      if (!doc.exists) {
        console.log(`    ⚠️  Question not found: ${docId}`);
        continue;
      }
      
      const data = doc.data();
      totalChecked++;
      
      // Extract letter from database answer
      let dbAnswer = data.correctAnswer || '';
      if (dbAnswer.includes('.')) {
        dbAnswer = dbAnswer.split('.')[0].trim();
      }
      dbAnswer = dbAnswer.toUpperCase();
      
      const expectedAnswer = correctAnswer.toUpperCase();
      
      if (dbAnswer !== expectedAnswer) {
        mismatches.push({
          subject: 'Mathematics',
          year: year,
          questionNum: questionNum,
          docId: docId,
          expected: expectedAnswer,
          actual: dbAnswer,
          questionText: data.questionText?.substring(0, 80) + '...',
          options: data.options
        });
        console.log(`    ❌ MISMATCH: Q${questionNum} - Expected: ${expectedAnswer}, Got: ${dbAnswer}`);
      } else {
        matchCount++;
      }
    }
  }
  
  // ====== VALIDATE RME 1999 ======
  console.log('\n📿 Checking RME 1999...');
  for (let i = 1; i <= 40; i++) {
    const qKey = `q${i}`;
    const correctAnswer = rme1999Answers[qKey];
    if (!correctAnswer) continue;
    
    const docId = `rme_1999_q${i}`;
    const doc = await db.collection('questions').doc(docId).get();
    
    if (!doc.exists) {
      console.log(`  ⚠️  Question not found: ${docId}`);
      continue;
    }
    
    const data = doc.data();
    totalChecked++;
    
    let dbAnswer = data.correctAnswer || '';
    if (dbAnswer.includes('.')) {
      dbAnswer = dbAnswer.split('.')[0].trim();
    }
    dbAnswer = dbAnswer.toUpperCase();
    
    const expectedAnswer = correctAnswer.toUpperCase();
    
    if (dbAnswer !== expectedAnswer) {
      mismatches.push({
        subject: 'RME',
        year: '1999',
        questionNum: i,
        docId: docId,
        expected: expectedAnswer,
        actual: dbAnswer,
        questionText: data.questionText?.substring(0, 80) + '...',
        options: data.options
      });
      console.log(`  ❌ MISMATCH: Q${i} - Expected: ${expectedAnswer}, Got: ${dbAnswer}`);
    } else {
      matchCount++;
    }
  }
  
  // ====== VALIDATE ICT ======
  console.log('\n💻 Checking ICT...');
  const ictAnswers = {
    '2023': ict2023,
    '2024': ict2024,
    '2025': ict2025
  };
  
  for (const [year, answers] of Object.entries(ictAnswers)) {
    console.log(`  Checking ${year}...`);
    
    for (const [qKey, correctAnswer] of Object.entries(answers)) {
      if (qKey === 'year' || qKey === 'subject') continue;
      
      const questionNum = qKey.replace('q', '');
      const docId = `ict_${year}_q${questionNum}`;
      const doc = await db.collection('questions').doc(docId).get();
      
      if (!doc.exists) {
        console.log(`    ⚠️  Question not found: ${docId}`);
        continue;
      }
      
      const data = doc.data();
      totalChecked++;
      
      let dbAnswer = data.correctAnswer || '';
      if (dbAnswer.includes('.')) {
        dbAnswer = dbAnswer.split('.')[0].trim();
      }
      dbAnswer = dbAnswer.toUpperCase();
      
      const expectedAnswer = correctAnswer.toUpperCase();
      
      if (dbAnswer !== expectedAnswer) {
        mismatches.push({
          subject: 'ICT',
          year: year,
          questionNum: questionNum,
          docId: docId,
          expected: expectedAnswer,
          actual: dbAnswer,
          questionText: data.questionText?.substring(0, 80) + '...',
          options: data.options
        });
        console.log(`    ❌ MISMATCH: Q${questionNum} - Expected: ${expectedAnswer}, Got: ${dbAnswer}`);
      } else {
        matchCount++;
      }
    }
  }
  
  // ====== VALIDATE GA (Ghanaian Language) ======
  console.log('\n🗣️  Checking Ga...');
  const gaAnswers = {
    '2022': ga2022,
    '2023': ga2023,
    '2024': ga2024
  };
  
  for (const [year, answers] of Object.entries(gaAnswers)) {
    console.log(`  Checking ${year}...`);
    
    for (const [qKey, correctAnswer] of Object.entries(answers)) {
      if (qKey === 'year' || qKey === 'subject') continue;
      
      const questionNum = qKey.replace('q', '');
      const docId = `ga_${year}_q${questionNum}`;
      const doc = await db.collection('questions').doc(docId).get();
      
      if (!doc.exists) {
        console.log(`    ⚠️  Question not found: ${docId}`);
        continue;
      }
      
      const data = doc.data();
      totalChecked++;
      
      let dbAnswer = data.correctAnswer || '';
      if (dbAnswer.includes('.')) {
        dbAnswer = dbAnswer.split('.')[0].trim();
      }
      dbAnswer = dbAnswer.toUpperCase();
      
      const expectedAnswer = correctAnswer.toUpperCase();
      
      if (dbAnswer !== expectedAnswer) {
        mismatches.push({
          subject: 'Ga',
          year: year,
          questionNum: questionNum,
          docId: docId,
          expected: expectedAnswer,
          actual: dbAnswer,
          questionText: data.questionText?.substring(0, 80) + '...',
          options: data.options
        });
        console.log(`    ❌ MISMATCH: Q${questionNum} - Expected: ${expectedAnswer}, Got: ${dbAnswer}`);
      } else {
        matchCount++;
      }
    }
  }
  
  // ====== VALIDATE ASANTE TWI ======
  console.log('\n🗣️  Checking Asante Twi...');
  const twiAnswers = {
    '2023': twi2023,
    '2024': twi2024
  };
  
  for (const [year, answers] of Object.entries(twiAnswers)) {
    console.log(`  Checking ${year}...`);
    
    for (const [qKey, correctAnswer] of Object.entries(answers)) {
      if (qKey === 'year' || qKey === 'subject') continue;
      
      const questionNum = qKey.replace('q', '');
      const docId = `asante_twi_${year}_q${questionNum}`;
      const doc = await db.collection('questions').doc(docId).get();
      
      if (!doc.exists) {
        console.log(`    ⚠️  Question not found: ${docId}`);
        continue;
      }
      
      const data = doc.data();
      totalChecked++;
      
      let dbAnswer = data.correctAnswer || '';
      if (dbAnswer.includes('.')) {
        dbAnswer = dbAnswer.split('.')[0].trim();
      }
      dbAnswer = dbAnswer.toUpperCase();
      
      const expectedAnswer = correctAnswer.toUpperCase();
      
      if (dbAnswer !== expectedAnswer) {
        mismatches.push({
          subject: 'Asante Twi',
          year: year,
          questionNum: questionNum,
          docId: docId,
          expected: expectedAnswer,
          actual: dbAnswer,
          questionText: data.questionText?.substring(0, 80) + '...',
          options: data.options
        });
        console.log(`    ❌ MISMATCH: Q${questionNum} - Expected: ${expectedAnswer}, Got: ${dbAnswer}`);
      } else {
        matchCount++;
      }
    }
  }
  
  // ====== SUMMARY ======
  console.log('\n' + '='.repeat(80));
  console.log('📊 VALIDATION SUMMARY');
  console.log('='.repeat(80));
  console.log(`Total Questions Checked: ${totalChecked}`);
  console.log(`✅ Correct Matches: ${matchCount} (${((matchCount/totalChecked)*100).toFixed(2)}%)`);
  console.log(`❌ Mismatches Found: ${mismatches.length} (${((mismatches.length/totalChecked)*100).toFixed(2)}%)`);
  console.log('='.repeat(80));
  
  if (mismatches.length > 0) {
    console.log('\n⚠️  CRITICAL: Found answer mismatches!\n');
    
    // Group by subject
    const grouped = {};
    mismatches.forEach(m => {
      if (!grouped[m.subject]) grouped[m.subject] = [];
      grouped[m.subject].push(m);
    });
    
    for (const [subject, items] of Object.entries(grouped)) {
      console.log(`\n📌 ${subject}: ${items.length} mismatches`);
      console.log('─'.repeat(80));
      
      items.slice(0, 10).forEach((mismatch, idx) => {
        console.log(`\n${idx + 1}. ${mismatch.year} Q${mismatch.questionNum} (${mismatch.docId})`);
        console.log(`   Expected: ${mismatch.expected}`);
        console.log(`   Database: ${mismatch.actual}`);
        console.log(`   Question: ${mismatch.questionText}`);
        if (mismatch.options) {
          console.log(`   Options:`);
          mismatch.options.forEach((opt, i) => console.log(`      ${i}: ${opt}`));
        }
      });
      
      if (items.length > 10) {
        console.log(`\n   ... and ${items.length - 10} more`);
      }
    }
    
    // Export full report
    fs.writeFileSync(
      'answer_validation_report.json',
      JSON.stringify(mismatches, null, 2)
    );
    console.log(`\n📄 Full report saved to answer_validation_report.json`);
  } else {
    console.log('\n🎉 Perfect! All answers match the official answer keys!');
  }
  
  process.exit(0);
}

validateAnswers().catch(console.error);
