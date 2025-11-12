const fs = require('fs').promises;
const path = require('path');

async function analyzeMissingQuestions() {
  // Load Social Studies
  const ssFile = path.join('assets', 'bece_json', 'bece_social_studies_questions.json');
  const ssData = await fs.readFile(ssFile, 'utf8');
  const ssQuestions = JSON.parse(ssData);
  
  // Load Integrated Science
  const isFile = path.join('assets', 'bece_json', 'bece_integrated_science_questions.json');
  const isData = await fs.readFile(isFile, 'utf8');
  const isQuestions = JSON.parse(isData);
  
  console.log('📊 MISSING QUESTIONS ANALYSIS\n');
  console.log('=' .repeat(80));
  
  // Analyze Social Studies
  console.log('\n🎓 SOCIAL STUDIES');
  console.log('-'.repeat(80));
  
  const ssByYear = {};
  ssQuestions.forEach(q => {
    if (!ssByYear[q.year]) ssByYear[q.year] = [];
    ssByYear[q.year].push(q.questionNumber);
  });
  
  const ssIncomplete = [];
  let ssTotalMissing = 0;
  
  for (let year = 1990; year <= 2025; year++) {
    const yearStr = year.toString();
    const questions = ssByYear[yearStr] || [];
    const count = questions.length;
    
    if (count < 40) {
      const missing = 40 - count;
      ssTotalMissing += missing;
      
      // Find which question numbers are missing
      const existing = new Set(questions);
      const missingNumbers = [];
      for (let i = 1; i <= 40; i++) {
        if (!existing.has(i)) missingNumbers.push(i);
      }
      
      ssIncomplete.push({ year, count, missing, missingNumbers });
      console.log(`${year}: ${count}/40 (${missing} missing) - Questions: ${missingNumbers.join(', ')}`);
    }
  }
  
  console.log(`\nTotal: ${ssQuestions.length}/1440 (${ssTotalMissing} missing)`);
  
  // Analyze Integrated Science
  console.log('\n\n🔬 INTEGRATED SCIENCE');
  console.log('-'.repeat(80));
  
  const isByYear = {};
  isQuestions.forEach(q => {
    if (!isByYear[q.year]) isByYear[q.year] = [];
    isByYear[q.year].push(q.questionNumber);
  });
  
  const isIncomplete = [];
  let isTotalMissing = 0;
  
  for (let year = 1990; year <= 2025; year++) {
    const yearStr = year.toString();
    const questions = isByYear[yearStr] || [];
    const count = questions.length;
    
    if (count < 40) {
      const missing = 40 - count;
      isTotalMissing += missing;
      
      // Find which question numbers are missing
      const existing = new Set(questions);
      const missingNumbers = [];
      for (let i = 1; i <= 40; i++) {
        if (!existing.has(i)) missingNumbers.push(i);
      }
      
      isIncomplete.push({ year, count, missing, missingNumbers });
      console.log(`${year}: ${count}/40 (${missing} missing) - Questions: ${missingNumbers.join(', ')}`);
    }
  }
  
  console.log(`\nTotal: ${isQuestions.length}/1440 (${isTotalMissing} missing)`);
  
  // Summary
  console.log('\n\n📈 SUMMARY');
  console.log('=' .repeat(80));
  console.log(`Social Studies: ${ssQuestions.length}/1440 (${((ssQuestions.length/1440)*100).toFixed(1)}%)`);
  console.log(`  - ${ssIncomplete.length} incomplete years`);
  console.log(`  - ${ssTotalMissing} total missing questions`);
  
  console.log(`\nIntegrated Science: ${isQuestions.length}/1440 (${((isQuestions.length/1440)*100).toFixed(1)}%)`);
  console.log(`  - ${isIncomplete.length} incomplete years`);
  console.log(`  - ${isTotalMissing} total missing questions`);
  
  const grandTotal = ssQuestions.length + isQuestions.length;
  const grandTotalPct = ((grandTotal/2880)*100).toFixed(1);
  const totalMissing = ssTotalMissing + isTotalMissing;
  const missingPct = ((totalMissing/2880)*100).toFixed(1);
  
  console.log(`\nGRAND TOTAL: ${grandTotal}/2880 (${grandTotalPct}%)`);
  console.log(`Missing: ${totalMissing} questions (${missingPct}%)`);
}

analyzeMissingQuestions().catch(console.error);
