const sharp = require('sharp');
const fs = require('fs');

async function convertRemaining() {
  const files = [
    { input: 'assets/landing_illustration.png', quality: 85 },
    { input: 'assets/uri.png', quality: 90 }
  ];

  for (const file of files) {
    try {
      const output = file.input.replace('.png', '.webp');
      const originalSize = fs.statSync(file.input).size;
      
      await sharp(file.input)
        .webp({ quality: file.quality })
        .toFile(output);
      
      const newSize = fs.statSync(output).size;
      const saved = ((originalSize - newSize) / originalSize * 100).toFixed(1);
      
      console.log(`✅ ${file.input}`);
      console.log(`   ${(originalSize/1024).toFixed(1)} KB → ${(newSize/1024).toFixed(1)} KB (${saved}% smaller)\n`);
    } catch (err) {
      console.log(`❌ Error: ${file.input} - ${err.message}`);
    }
  }
}

convertRemaining();
