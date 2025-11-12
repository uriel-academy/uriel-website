const fs = require('fs');
const { PDFParse } = require('pdf-parse');

async function extractPDF(pdfPath, outputPath) {
  try {
    console.log(`📄 Extracting ${pdfPath}...`);
    const dataBuffer = fs.readFileSync(pdfPath);
    const data = await PDFParse(dataBuffer);
    
    fs.mkdirSync('./extracted_english', { recursive: true });
    fs.writeFileSync(outputPath, data.text);
    
    console.log(`✅ Extracted to ${outputPath}`);
    console.log(`   Pages: ${data.numpages}, Text length: ${data.text.length} chars\n`);
    return data.text;
  } catch (error) {
    console.error(`❌ Error extracting ${pdfPath}:`, error.message);
    throw error;
  }
}

// Run if called directly
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log('Usage: node extract_pdf_to_text.js <pdf-path> <output-path>');
    console.log('Example: node extract_pdf_to_text.js "./assets/bece English/bece english 2024 questions.pdf" "./extracted_english/english_2024_raw.txt"');
    process.exit(1);
  }
  
  extractPDF(args[0], args[1])
    .then(() => console.log('✅ Done!'))
    .catch(err => {
      console.error('❌ Failed:', err.message);
      process.exit(1);
    });
}

module.exports = { extractPDF };
