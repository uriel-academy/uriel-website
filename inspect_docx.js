const mammoth = require('mammoth');

mammoth.extractRawText({ path: './assets/Mathematics/bece mathematics 2024 questions.docx' })
  .then(result => {
    const lines = result.value.split('\n');
    console.log('First 80 lines:\n');
    lines.slice(0, 80).forEach((line, i) => {
      if (line.trim()) {
        console.log(`Line ${i}: ${line.trim().substring(0, 120)}`);
      }
    });
  })
  .catch(err => console.error(err));
