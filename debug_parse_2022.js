const mammoth = require('mammoth');
const path = require('path');

async function debugParse() {
  const filePath = path.join('assets', 'Integrated Science', 'bece integrated science 2022 questions.docx');
  
  const result = await mammoth.extractRawText({ path: filePath });
  let text = result.value;
  
  // Clean up text
  text = text.replace(/\r/g, '');
  
  // Split by question numbers
  const blocks = text.split(/\n{1,3}(\d+)\.\s*\n/);
  
  console.log(`Total blocks: ${blocks.length}`);
  console.log(`Expected: 81 (1 + 40*2) for 40 questions\n`);
  
  // Check last few blocks
  console.log('Last 10 blocks:');
  for (let i = Math.max(0, blocks.length - 10); i < blocks.length; i++) {
    const content = blocks[i];
    if (typeof content === 'string') {
      const preview = content.substring(0, 100).replace(/\n/g, ' ');
      console.log(`[${i}] ${preview}...`);
    }
  }
  
  // Find block 40
  console.log('\n\nLooking for "40" in blocks...');
  for (let i = 0; i < blocks.length; i++) {
    if (blocks[i] === '40') {
      console.log(`Found "40" at block[${i}]`);
      console.log(`Next block [${i+1}]:`);
      console.log(blocks[i+1]);
      break;
    }
  }
}

debugParse().catch(console.error);
