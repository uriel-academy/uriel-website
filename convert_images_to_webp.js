const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

console.log('🖼️  Image Conversion Script - PNG/JPG to WebP\n');
console.log('='.repeat(60));

// Directories to process
const directories = [
  'assets/leaderboards_rank',
  'assets/storybook_covers',
  'assets/notes_cover'
];

let totalSaved = 0;
let filesConverted = 0;

async function convertImage(inputPath, outputPath) {
  try {
    const originalSize = fs.statSync(inputPath).size;
    
    await sharp(inputPath)
      .webp({ quality: 90 })
      .toFile(outputPath);
    
    const newSize = fs.statSync(outputPath).size;
    const saved = originalSize - newSize;
    const savingPercent = ((saved / originalSize) * 100).toFixed(1);
    
    console.log(`  ✅ ${path.basename(inputPath)}`);
    console.log(`     Original: ${(originalSize/1024).toFixed(1)} KB → WebP: ${(newSize/1024).toFixed(1)} KB (${savingPercent}% smaller)`);
    
    return saved;
  } catch (error) {
    console.log(`  ❌ Failed: ${path.basename(inputPath)} - ${error.message}`);
    return 0;
  }
}

async function processDirectory(dir) {
  if (!fs.existsSync(dir)) {
    console.log(`\n⚠️  Directory not found: ${dir}`);
    return;
  }
  
  console.log(`\n📁 Processing: ${dir}`);
  
  const files = fs.readdirSync(dir);
  const images = files.filter(f => /\.(png|jpg|jpeg)$/i.test(f));
  
  for (const img of images) {
    const inputPath = path.join(dir, img);
    const outputPath = inputPath.replace(/\.(png|jpg|jpeg)$/i, '.webp');
    
    // Skip if WebP already exists and is newer
    if (fs.existsSync(outputPath)) {
      const inputTime = fs.statSync(inputPath).mtimeMs;
      const outputTime = fs.statSync(outputPath).mtimeMs;
      
      if (outputTime > inputTime) {
        console.log(`  ⏭️  Skipping (already converted): ${img}`);
        continue;
      }
    }
    
    const saved = await convertImage(inputPath, outputPath);
    if (saved > 0) {
      totalSaved += saved;
      filesConverted++;
    }
  }
}

async function main() {
  try {
    for (const dir of directories) {
      await processDirectory(dir);
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('✨ Conversion Complete!');
    console.log(`📊 Files converted: ${filesConverted}`);
    console.log(`💾 Total space saved: ${(totalSaved/1024/1024).toFixed(2)} MB`);
    console.log('\n⚠️  Remember to update image references in your code from .png/.jpg to .webp');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

main();
