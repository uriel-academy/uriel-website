const mammoth = require('mammoth');
const path = require('path');

async function checkQ27Text() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  const text = result.value.replace(/\r/g, '');
  
  const q27Index = text.indexOf('\n27.\n');
  console.log('Q27 area (500 chars):');
  console.log('---');
  console.log(text.substring(q27Index, q27Index + 500));
  console.log('---');
  
  // Show with escape characters
  console.log('\n\nWith escape characters visible:');
  console.log(JSON.stringify(text.substring(q27Index, q27Index + 500)));
}

checkQ27Text().catch(console.error);
