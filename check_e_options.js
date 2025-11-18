const mammoth = require('mammoth');

mammoth.extractRawText({ path: './assets/Mathematics/bece mathematics 2024 questions.docx' })
  .then(result => {
    const lines = result.value.split('\n').map(l => l.trim());
    
    console.log('Checking for E options in 2024...\n');
    let foundE = false;
    
    for (let i = 0; i < lines.length; i++) {
      if (lines[i] === 'E.' || lines[i] === 'E)') {
        foundE = true;
        console.log(`Found E option at line ${i}:`);
        console.log('Context:');
        for (let j = Math.max(0, i - 8); j <= Math.min(lines.length - 1, i + 3); j++) {
          console.log(`  ${j}: ${lines[j].substring(0, 80)}`);
        }
        console.log('---\n');
        if (foundE) break;
      }
    }
    
    if (!foundE) {
      console.log('No E options found in 2024. Checking option format...\n');
      // Check if D options have merged E
      for (let i = 0; i < lines.length; i++) {
        if (lines[i] === 'D.') {
          console.log(`Found D option at line ${i}:`);
          console.log('Next 10 lines:');
          for (let j = i; j <= Math.min(lines.length - 1, i + 10); j++) {
            console.log(`  ${j}: ${lines[j].substring(0, 100)}`);
          }
          break;
        }
      }
    }
  })
  .catch(err => console.error(err));
