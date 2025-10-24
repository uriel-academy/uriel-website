const fs = require('fs');
const path = require('path');

const ictDir = 'assets/bece_ict';
const years = [2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022];

let allQuestions = [];

years.forEach(year => {
  try {
    const questionsFile = path.join(ictDir, year === 2011 ? `bece_ict_${year}_questions .json` : `bece_ict_${year}_questions.json`);
    const answersFile = path.join(ictDir, `bece_ict_${year}_answers.json`);
    
    const questionsData = JSON.parse(fs.readFileSync(questionsFile, 'utf8'));
    const answersData = JSON.parse(fs.readFileSync(answersFile, 'utf8'));
    
    const questions = questionsData.multiple_choice;
    const answers = answersData.multiple_choice;
    
    Object.keys(questions).forEach(qKey => {
      const qNum = parseInt(qKey.substring(1));
      const question = questions[qKey];
      const answer = answers[qKey];
      
      allQuestions.push({
        year: year,
        questionNumber: qNum,
        questionText: question.question,
        options: question.possibleAnswers,
        correctAnswer: answer.split('. ')[0], // e.g., 'B' from 'B. Keyboard'
        fullAnswer: answer
      });
    });
    
    console.log(`Processed ${Object.keys(questions).length} questions for ${year}`);
  } catch (e) {
    console.error(`Error processing ${year}:`, e.message);
  }
});

console.log(`Total questions: ${allQuestions.length}`);

// Generate the import script
const script = `// Import ICT questions
const https = require('https');

const data = JSON.stringify({
  data: {}
});

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/importICTQuestions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🚀 Calling importICTQuestions Cloud Function...');

const req = https.request(options, (res) => {
  let responseData = '';
  
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('📤 Response Status:', res.statusCode);
    console.log('📄 Response Data:', responseData);
    
    try {
      const result = JSON.parse(responseData);
      if (result.result && result.result.success) {
        console.log('🎉 SUCCESS: ICT questions imported!');
        console.log('📝 Message:', result.result.message);
        console.log('📊 Questions imported:', result.result.questionsImported);
      } else {
        console.log('❌ Error in response:', result);
      }
    } catch (e) {
      console.log('📄 Raw response:', responseData);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error);
});

req.write(data);
req.end();
`;

fs.writeFileSync('import_ict_now.js', script);
console.log('Generated import_ict_now.js');