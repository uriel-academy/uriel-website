const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

/**
 * Check if a DOCX file contains images
 * DOCX files are ZIP archives - images are stored in word/media/
 */
function checkDocxForImages(docxPath) {
    try {
        const zip = new AdmZip(docxPath);
        const zipEntries = zip.getEntries();
        
        // Look for media folder which contains images
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

/**
 * Scan all DOCX files in a directory
 */
function scanDirectory(dirPath, subjectName) {
    const results = [];
    
    if (!fs.existsSync(dirPath)) {
        console.log(`Directory not found: ${dirPath}`);
        return results;
    }
    
    const files = fs.readdirSync(dirPath);
    
    for (const file of files) {
        if (file.endsWith('.docx')) {
            const fullPath = path.join(dirPath, file);
            const imageCheck = checkDocxForImages(fullPath);
            
            if (imageCheck.hasImages) {
                results.push({
                    subject: subjectName,
                    file: file,
                    imageCount: imageCheck.imageCount,
                    path: fullPath
                });
            }
        }
    }
    
    return results;
}

// Main execution
console.log('Scanning DOCX files for embedded images...\n');

const subjectsToCheck = [
    { name: 'English', path: 'assets/bece English' },
    { name: 'Integrated Science', path: 'assets/Integrated Science' },
    { name: 'Social Studies', path: 'assets/Social Studies' },
    { name: 'ICT', path: 'assets/bece_ict' },
    { name: 'French', path: 'assets/bece french' },
    { name: 'RME', path: 'assets/bece_rme_1999_2022' },
    { name: 'Career Technology', path: 'assets/bece Career Technology' },
    { name: 'Creative Arts', path: 'assets/bece Creative Art and Design' }
];

const allResults = [];

for (const subject of subjectsToCheck) {
    console.log(`Checking ${subject.name}...`);
    const results = scanDirectory(subject.path, subject.name);
    allResults.push(...results);
    console.log(`  Found ${results.length} files with images\n`);
}

console.log('\n=== SUMMARY ===');
console.log(`Total files with images: ${allResults.length}\n`);

// Group by subject
const bySubject = {};
for (const result of allResults) {
    if (!bySubject[result.subject]) {
        bySubject[result.subject] = [];
    }
    bySubject[result.subject].push(result);
}

for (const [subject, files] of Object.entries(bySubject)) {
    const totalImages = files.reduce((sum, f) => sum + f.imageCount, 0);
    console.log(`${subject}: ${files.length} files, ${totalImages} total images`);
    
    // Show sample files
    if (files.length > 0 && files.length <= 5) {
        files.forEach(f => {
            console.log(`  - ${f.file} (${f.imageCount} images)`);
        });
    } else if (files.length > 5) {
        console.log(`  Sample files:`);
        files.slice(0, 3).forEach(f => {
            console.log(`  - ${f.file} (${f.imageCount} images)`);
        });
        console.log(`  ... and ${files.length - 3} more`);
    }
    console.log();
}

// Save detailed results to JSON
fs.writeFileSync(
    'docx_images_report.json',
    JSON.stringify(allResults, null, 2)
);

console.log('Detailed report saved to: docx_images_report.json');
