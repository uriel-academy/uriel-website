const mammoth = require('mammoth');
const path = require('path');

async function checkQ27Q28() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  let text = result.value;
  text = text.replace(/\r/g, '');
  
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);
  
  console.log('Looking for blocks 27 and 28...\n');
  
  for (let i = 0; i < blocks.length; i++) {
    if (blocks[i] === '27' || blocks[i] === '28' || blocks[i] === '1' || blocks[i] === '3') {
      console.log(`[${i}] = "${blocks[i]}"`);
      if (i + 1 < blocks.length) {
        const nextBlock = blocks[i + 1];
        console.log(`[${i+1}] = "${nextBlock.substring(0, 100).replace(/\n/g, ' ')}..."`);
      }
      console.log('');
    }
  }
}

checkQ27Q28().catch(console.error);
