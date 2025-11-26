const data = require('./bece_theory_english.json');

const years = [1990, 1995, 2000, 2005, 2010, 2015, 2020, 2025];

years.forEach(y => {
  const q1 = data.find(q => q.year === y && q.questionNumber === 1);
  if (q1) {
    console.log(`\n=== ${y} ===`);
    const numQuestions = data.filter(q => q.year === y).length;
    console.log('Number of questions:', numQuestions);
    console.log('\nText preview (first 400 chars):');
    console.log(q1.questionText.substring(0, 400));
  }
});
