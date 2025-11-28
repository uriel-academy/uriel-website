const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

/**
 * Extract images from DOCX files and save them with meaningful names
 */
function extractImagesFromDocx(docxPath, outputDir, year) {
    try {
        const zip = new AdmZip(docxPath);
        const zipEntries = zip.getEntries();
        
        // Find all image files in word/media/
        const mediaFiles = zipEntries.filter(entry => 
            entry.entryName.startsWith('word/media/') && 
            !entry.isDirectory
        );
        
        if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir, { recursive: true });
        }
        
        const extractedFiles = [];
        
        mediaFiles.forEach((entry, index) => {
            const ext = path.extname(entry.entryName);
            // Name files as: science_YEAR_imgN.ext
            const newFileName = `science_${year}_img${index + 1}${ext}`;
            const outputPath = path.join(outputDir, newFileName);
            
            // Extract the file
            zip.extractEntryTo(entry, outputDir, false, true, false, newFileName);
            
            extractedFiles.push({
                originalName: entry.entryName,
                newName: newFileName,
                path: outputPath,
                year: year
            });
            
            console.log(`  Extracted: ${newFileName}`);
        });
        
        return extractedFiles;
        
    } catch (error) {
        console.error(`Error extracting from ${docxPath}:`, error.message);
        return [];
    }
}

// Main execution
console.log('Extracting images from Integrated Science DOCX files...\n');

const docxFiles = [
    { year: '2002', path: 'assets/Integrated Science/bece integrated science 2002 questions.docx', imageCount: 3 },
    { year: '2003', path: 'assets/Integrated Science/bece integrated science 2003 questions.docx', imageCount: 1 },
    { year: '2004', path: 'assets/Integrated Science/bece integrated science 2004 questions .docx', imageCount: 2 },
    { year: '2005', path: 'assets/Integrated Science/bece integrated science 2005 questions.docx', imageCount: 5 },
    { year: '2009', path: 'assets/Integrated Science/bece integrated science 2009 questions.docx', imageCount: 2 },
    { year: '2010', path: 'assets/Integrated Science/bece integrated science 2010 questions.docx', imageCount: 5 },
    { year: '2022', path: 'assets/Integrated Science/bece integrated science 2022 questions.docx', imageCount: 1 }
];

const outputDir = 'assets/science_images';
const allExtractedFiles = [];

for (const docx of docxFiles) {
    console.log(`Processing ${docx.year} (expected ${docx.imageCount} images)...`);
    const extracted = extractImagesFromDocx(docx.path, outputDir, docx.year);
    allExtractedFiles.push(...extracted);
    console.log();
}

console.log(`\n=== EXTRACTION COMPLETE ===`);
console.log(`Total images extracted: ${allExtractedFiles.length}`);
console.log(`Output directory: ${outputDir}`);

// Save extraction report
const report = {
    totalImages: allExtractedFiles.length,
    outputDirectory: outputDir,
    files: allExtractedFiles,
    extractedAt: new Date().toISOString()
};

fs.writeFileSync(
    'science_images_extraction_report.json',
    JSON.stringify(report, null, 2)
);

console.log('\nExtraction report saved to: science_images_extraction_report.json');
console.log('\nNext steps:');
console.log('1. Review extracted images in assets/science_images/');
console.log('2. Create an image mapping JSON file (science_image_mapping.json)');
console.log('3. Run the conversion and upload script');
