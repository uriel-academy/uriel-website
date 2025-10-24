const fs = require('fs');
const path = require('path');

const ictDir = path.join(__dirname, 'assets', 'bece_ict');
const years = [2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022];

let allQuestions = [];

years.forEach(year => {
  try {
    const questionsFile = year === 2011 ? path.join(ictDir, `bece_ict_${year}_questions .json`) : path.join(ictDir, `bece_ict_${year}_questions.json`);
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

// Write to a temporary file for embedding
fs.writeFileSync('ict_questions_data.json', JSON.stringify(allQuestions, null, 2));
console.log('Data written to ict_questions_data.json');