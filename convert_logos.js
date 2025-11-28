const sharp = require('sharp');
const fs = require('fs');

async function convertLogos() {
  const files = [
    { input: 'assets/google_logo.png', quality: 90 },
    { input: 'assets/facebook_logo.png', quality: 90 },
    { input: 'assets/twitter_logo.png', quality: 90 },
    { input: 'assets/apple_logo.png', quality: 90 }
  ];

  let totalSaved = 0;

  for (const file of files) {
    try {
      if (!fs.existsSync(file.input)) {
        console.log(`⚠️  File not found: ${file.input}`);
        continue;
      }

      const output = file.input.replace('.png', '.webp');
      const originalSize = fs.statSync(file.input).size;
      
      await sharp(file.input)
        .webp({ quality: file.quality })
        .toFile(output);
      
      const newSize = fs.statSync(output).size;
      const saved = originalSize - newSize;
      const savingPercent = ((saved / originalSize) * 100).toFixed(1);
      
      totalSaved += saved;
      
      console.log(`✅ ${file.input}`);
      console.log(`   ${(originalSize/1024).toFixed(1)} KB → ${(newSize/1024).toFixed(1)} KB (${savingPercent}% smaller)\n`);
    } catch (err) {
      console.log(`❌ Error: ${file.input} - ${err.message}`);
    }
  }

  console.log(`\nTotal saved: ${(totalSaved/1024).toFixed(1)} KB`);
}

convertLogos();
