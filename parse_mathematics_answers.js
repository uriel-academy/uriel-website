const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');

async function parseAnswers() {
  console.log('Parsing answers from docx file...\n');
  
  const answersFile = 'assets/Mathematics/bece mathematics 1990-2025 answers.docx';
  
  if (!fs.existsSync(answersFile)) {
    console.error('Answers file not found!');
    process.exit(1);
  }
  
  const result = await mammoth.extractRawText({path: answersFile});
  const text = result.value;
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);
  
  const answers = {};
  let currentYear = null;
  
  console.log('Processing lines...\n');
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Check if line is a year (e.g., "1990", "2025")
    const yearMatch = line.match(/^(19\d{2}|20[0-2]\d)$/);
    if (yearMatch) {
      currentYear = yearMatch[1];
      answers[currentYear] = {};
      console.log(`Found year: ${currentYear}`);
      continue;
    }
    
    // Check if line contains answers (e.g., "1. A  2. B  3. C")
    if (currentYear && line.match(/^\d+\.\s*[A-E]/)) {
      // Parse answer line
      const answerPattern = /(\d+)\.\s*([A-E])/g;
      let match;
      
      while ((match = answerPattern.exec(line)) !== null) {
        const questionNum = parseInt(match[1]);
        const answer = match[2];
        answers[currentYear][questionNum] = answer;
      }
    }
  }
  
  // Display summary
  console.log('\n' + '='.repeat(50));
  console.log('Parsed answers summary:');
  console.log('='.repeat(50));
  
  let totalQuestions = 0;
  const years = Object.keys(answers).sort();
  
  for (const year of years) {
    const questionCount = Object.keys(answers[year]).length;
    totalQuestions += questionCount;
    console.log(`${year}: ${questionCount} answers`);
  }
  
  console.log('='.repeat(50));
  console.log(`Total: ${totalQuestions} answers across ${years.length} years`);
  console.log('='.repeat(50));
  
  // Show sample from first and last year
  if (years.length > 0) {
    const firstYear = years[0];
    const lastYear = years[years.length - 1];
    
    console.log(`\nSample from ${firstYear}:`);
    const firstYearAnswers = answers[firstYear];
    Object.keys(firstYearAnswers).slice(0, 10).forEach(q => {
      console.log(`  Q${q}: ${firstYearAnswers[q]}`);
    });
    
    console.log(`\nSample from ${lastYear}:`);
    const lastYearAnswers = answers[lastYear];
    Object.keys(lastYearAnswers).slice(0, 10).forEach(q => {
      console.log(`  Q${q}: ${lastYearAnswers[q]}`);
    });
  }
  
  // Save to JSON file
  const outputFile = 'mathematics_answers.json';
  fs.writeFileSync(outputFile, JSON.stringify(answers, null, 2));
  console.log(`\n✅ Answers saved to: ${outputFile}`);
  
  return answers;
}

parseAnswers().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
