const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');

const mathDir = 'assets/Mathematics';
const outputDir = 'assets/mathematics_images';

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

async function extractImagesFromDocx(filePath, year) {
  console.log(`\nProcessing ${year}...`);
  
  let imageCount = 0;
  const imageMap = {}; // Maps question numbers to image filenames
  
  // Track current question context
  let currentQuestionNumber = null;
  let textBuffer = '';
  
  const options = {
    convertImage: mammoth.images.imgElement(function(image) {
      imageCount++;
      
      return image.read("base64").then(function(imageBuffer) {
        // Determine file extension
        const ext = image.contentType === 'image/png' ? 'png' : 'jpg';
        
        // Try to determine which question this image belongs to
        // Look for question number in recent text
        const questionMatch = textBuffer.match(/(\d+)\.\s*$/);
        const questionNum = questionMatch ? parseInt(questionMatch[1]) : currentQuestionNumber || imageCount;
        
        const filename = `math_${year}_q${questionNum}_img${imageCount}.${ext}`;
        const filepath = path.join(outputDir, filename);
        
        // Save image file
        fs.writeFileSync(filepath, imageBuffer, {encoding: 'base64'});
        console.log(`  Saved: ${filename} (Q${questionNum})`);
        
        // Track which question this image belongs to
        if (!imageMap[questionNum]) {
          imageMap[questionNum] = [];
        }
        imageMap[questionNum].push(filename);
        
        return {
          src: filepath
        };
      });
    })
  };
  
  try {
    const result = await mammoth.convertToHtml({path: filePath}, options);
    
    // Parse the HTML to also extract text context
    const html = result.value;
    
    // Look for question numbers in the text
    const questionMatches = html.matchAll(/<p[^>]*>(\d+)\.<\/p>/g);
    for (const match of questionMatches) {
      currentQuestionNumber = parseInt(match[1]);
    }
    
    console.log(`  Total images extracted: ${imageCount}`);
    
    return { imageCount, imageMap };
    
  } catch (error) {
    console.error(`  Error processing ${year}:`, error.message);
    return { imageCount: 0, imageMap: {} };
  }
}

async function extractAllImages() {
  console.log('Starting image extraction from mathematics .docx files...\n');
  
  const years = [];
  for (let year = 1990; year <= 2025; year++) {
    years.push(year);
  }
  
  let totalImages = 0;
  const allImageMaps = {};
  
  for (const year of years) {
    const filename = `bece mathematics ${year} questions.docx`;
    const filePath = path.join(mathDir, filename);
    
    if (!fs.existsSync(filePath)) {
      console.log(`Skipping ${year} - file not found`);
      continue;
    }
    
    const result = await extractImagesFromDocx(filePath, year);
    totalImages += result.imageCount;
    
    if (Object.keys(result.imageMap).length > 0) {
      allImageMaps[year] = result.imageMap;
    }
  }
  
  console.log('\n' + '='.repeat(50));
  console.log(`Total images extracted: ${totalImages}`);
  console.log(`Years with images: ${Object.keys(allImageMaps).length}`);
  
  // Save mapping to JSON file
  const mappingFile = path.join(outputDir, 'image_mapping.json');
  fs.writeFileSync(mappingFile, JSON.stringify(allImageMaps, null, 2));
  console.log(`\nImage mapping saved to: ${mappingFile}`);
  
  // Show summary
  console.log('\nSummary by year:');
  Object.keys(allImageMaps).sort().forEach(year => {
    const questionCount = Object.keys(allImageMaps[year]).length;
    const imageCount = Object.values(allImageMaps[year]).flat().length;
    console.log(`  ${year}: ${imageCount} images across ${questionCount} questions`);
  });
}

extractAllImages().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
