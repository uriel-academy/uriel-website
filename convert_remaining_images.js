const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

console.log('Converting remaining PNG images to WebP...\n');

const filesToConvert = [
  'assets/english_jhs1.png',
  'assets/english_jhs2.png',
  'assets/english_jhs3.png',
  'assets/social-studies_jhs1.png',
  'assets/social-studies_jhs2.png',
  'assets/social-studies_jhs3.png',
  'assets/rme_jhs1.png',
  'assets/rme_jhs2.png',
  'assets/rme_jhs3.png',
  'assets/profile_pic_1.png',
  'assets/profile_pic_2.png',
  'assets/profile_pic_3.png',
  'assets/profile_pic_4.png',
  'assets/uri.png',
  'assets/landing_illustration.png',
  'assets/uriel_favicon.png',
  'assets/apple_logo.png',
  'assets/google_logo.png',
  'assets/facebook_logo.png',
  'assets/twitter_logo.png'
];

let totalSaved = 0;
let filesConverted = 0;

async function convertImage(inputPath) {
  if (!fs.existsSync(inputPath)) {
    console.log(`⚠️  File not found: ${inputPath}`);
    return 0;
  }
  
  try {
    const outputPath = inputPath.replace(/\.png$/i, '.webp');
    const originalSize = fs.statSync(inputPath).size;
    
    await sharp(inputPath)
      .webp({ quality: 90 })
      .toFile(outputPath);
    
    const newSize = fs.statSync(outputPath).size;
    const saved = originalSize - newSize;
    const savingPercent = ((saved / originalSize) * 100).toFixed(1);
    
    console.log(`✅ ${path.basename(inputPath)}`);
    console.log(`   ${(originalSize/1024).toFixed(1)} KB → ${(newSize/1024).toFixed(1)} KB (${savingPercent}% smaller)`);
    
    return saved;
  } catch (error) {
    console.log(`❌ Failed: ${path.basename(inputPath)} - ${error.message}`);
    return 0;
  }
}

async function main() {
  for (const file of filesToConvert) {
    const saved = await convertImage(file);
    if (saved > 0) {
      totalSaved += saved;
      filesConverted++;
    }
  }
  
  console.log('\n' + '='.repeat(60));
  console.log(`✨ Conversion Complete!`);
  console.log(`📊 Files converted: ${filesConverted}`);
  console.log(`💾 Total space saved: ${(totalSaved/1024/1024).toFixed(2)} MB`);
}

main();
