const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

function checkDocxForImages(docxPath) {
    try {
        const zip = new AdmZip(docxPath);
        const zipEntries = zip.getEntries();
        
        const mediaFiles = zipEntries.filter(entry => 
            entry.entryName.startsWith('word/media/') && 
            !entry.isDirectory
        );
        
        return {
            hasImages: mediaFiles.length > 0,
            imageCount: mediaFiles.length,
            imageFiles: mediaFiles.map(e => e.entryName)
        };
    } catch (error) {
        return { 
            hasImages: false, 
            imageCount: 0, 
            error: error.message 
        };
    }
}

console.log('Checking Social Studies DOCX files for images...\n');

const socialStudiesDir = 'assets/Social Studies';
const files = fs.readdirSync(socialStudiesDir)
    .filter(f => f.endsWith('.docx') && f.includes('questions'));

let totalImages = 0;
const filesWithImages = [];

for (const file of files) {
    const fullPath = path.join(socialStudiesDir, file);
    const result = checkDocxForImages(fullPath);
    
    if (result.hasImages) {
        console.log(`✓ ${file}: ${result.imageCount} images`);
        filesWithImages.push({ file, imageCount: result.imageCount, path: fullPath });
        totalImages += result.imageCount;
    }
}

console.log(`\n=== SUMMARY ===`);
console.log(`Files checked: ${files.length}`);
console.log(`Files with images: ${filesWithImages.length}`);
console.log(`Total images found: ${totalImages}`);

if (filesWithImages.length > 0) {
    console.log('\n=== FILES WITH IMAGES ===');
    filesWithImages.forEach(f => {
        const year = f.file.match(/\d{4}/)?.[0] || 'unknown';
        console.log(`${year}: ${f.imageCount} images`);
    });
    
    // Save report
    fs.writeFileSync(
        'social_studies_images_report.json',
        JSON.stringify(filesWithImages, null, 2)
    );
    console.log('\nReport saved to: social_studies_images_report.json');
}
