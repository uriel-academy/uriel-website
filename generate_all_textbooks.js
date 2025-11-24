/**
 * Script to generate all 3 English textbooks via Cloud Functions
 * Run with: node generate_all_textbooks.js
 */

const https = require('https');

// Your Firebase project configuration
const PROJECT_ID = 'uriel-academy-41fb0';
const REGION = 'us-central1';
const FUNCTION_NAME = 'generateEnglishTextbooks';

// Construct the Cloud Function URL for callable functions
const FUNCTION_URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;

/**
 * Call Cloud Function to generate textbook
 */
async function generateTextbook(year) {
  return new Promise((resolve, reject) => {
    // Firebase callable functions expect data wrapped in a "data" property
    const payload = JSON.stringify({
      data: { year }
    });
    
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      },
      timeout: 600000 // 10 minutes
    };

    console.log(`\n${'='.repeat(60)}`);
    console.log(`🚀 Starting generation for: ${year}`);
    console.log(`📡 URL: ${FUNCTION_URL}`);
    console.log(`⏰ Started at: ${new Date().toLocaleTimeString()}`);
    console.log(`${'='.repeat(60)}\n`);

    const req = https.request(FUNCTION_URL, options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
        process.stdout.write('.');
      });

      res.on('end', () => {
        console.log('\n');
        if (res.statusCode === 200) {
          try {
            const result = JSON.parse(responseData);
            console.log(`✅ SUCCESS: ${year} textbook generated!`);
            console.log(`📊 Details:`, JSON.stringify(result, null, 2));
            console.log(`⏰ Completed at: ${new Date().toLocaleTimeString()}`);
            resolve(result);
          } catch (e) {
            console.log(`✅ SUCCESS: ${year} textbook generated!`);
            console.log(`📄 Raw response:`, responseData);
            resolve({ success: true, year });
          }
        } else {
          console.error(`❌ ERROR: Status ${res.statusCode}`);
          console.error(`📄 Response:`, responseData);
          reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ REQUEST ERROR for ${year}:`, error.message);
      reject(error);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Request timeout for ${year}`));
    });

    req.write(payload);
    req.end();
  });
}

/**
 * Generate all textbooks sequentially
 */
async function generateAllTextbooks() {
  const years = ['JHS 1', 'JHS 2', 'JHS 3'];
  const results = [];
  
  console.log('\n' + '🎓'.repeat(30));
  console.log('📚 ENGLISH TEXTBOOK GENERATION - ALL YEARS');
  console.log('🎓'.repeat(30));
  console.log(`\n⏰ Total estimated time: 15-25 minutes`);
  console.log(`🤖 Using Claude 3.5 Sonnet`);
  console.log(`📍 Generating: ${years.join(', ')}\n`);

  for (const year of years) {
    try {
      const result = await generateTextbook(year);
      results.push({ year, success: true, result });
      
      // Delay between generations to avoid rate limits
      if (year !== 'JHS 3') {
        console.log(`\n⏸️  Waiting 3 seconds before next generation...\n`);
        await new Promise(resolve => setTimeout(resolve, 3000));
      }
    } catch (error) {
      console.error(`\n❌ Failed to generate ${year}:`, error.message);
      results.push({ year, success: false, error: error.message });
    }
  }

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 GENERATION SUMMARY');
  console.log('='.repeat(60) + '\n');

  results.forEach(({ year, success, result, error }) => {
    if (success) {
      console.log(`✅ ${year}: SUCCESS`);
    } else {
      console.log(`❌ ${year}: FAILED - ${error}`);
    }
  });

  const successCount = results.filter(r => r.success).length;
  console.log(`\n🎯 Total: ${successCount}/${years.length} textbooks generated successfully`);
  console.log(`⏰ Completed at: ${new Date().toLocaleString()}\n`);

  if (successCount === years.length) {
    console.log('🎉 All textbooks generated successfully!');
    console.log('📱 Check your app at /textbooks/library to view them.\n');
  } else {
    console.log('⚠️  Some textbooks failed. Check errors above.\n');
  }
}

// Run the generation
generateAllTextbooks().catch(error => {
  console.error('\n💥 FATAL ERROR:', error);
  process.exit(1);
});
