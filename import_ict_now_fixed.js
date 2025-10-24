// Import ICT questions using HTTP request to Cloud Function
const https = require('https');

// Function URL for the deployed Cloud Function
const functionUrl = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/importICTQuestions';

async function importICTQuestions() {
  try {
    console.log('🚀 Calling importICTQuestions Cloud Function via HTTP...');

    // Make HTTP POST request to the Cloud Function
    const response = await new Promise((resolve, reject) => {
      const req = https.request(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Node.js Import Script'
        }
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            const result = JSON.parse(data);
            resolve(result);
          } catch (e) {
            reject(new Error(`Failed to parse response: ${data}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(error);
      });

      req.end();
    });

    console.log('📡 Response:', response);

    if (response && response.success) {
      console.log('🎉 SUCCESS: ICT questions imported!');
      console.log('📝 Message:', response.message);
      console.log('📊 Questions imported:', response.questionsImported);
    } else {
      console.log('❌ Error in response:', response);
    }

    return response;

  } catch (error) {
    console.error('❌ HTTP request error:', error);
    throw error;
  }
}

importICTQuestions()
  .then((result) => {
    console.log('✅ Import script completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Import script failed:', error);
    process.exit(1);
  });