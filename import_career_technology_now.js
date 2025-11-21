// Import Career Technology questions using Cloud Function
const https = require('https');

const data = JSON.stringify({
  data: {}
});

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/importCareerTechnologyQuestions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🚀 Calling importCareerTechnologyQuestions Cloud Function...');

const req = https.request(options, (res) => {
  let responseData = '';

  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    console.log('📤 Response Status:', res.statusCode);
    console.log('📄 Response Data:', responseData);

    try {
      const result = JSON.parse(responseData);
      if (result.result && result.result.success) {
        console.log('🎉 SUCCESS: Career Technology questions imported!');
        console.log('📝 Message:', result.result.message);
        console.log('📊 Questions imported:', result.result.questionsImported);
      } else {
        console.log('❌ Error in response:', result);
      }
    } catch (e) {
      console.log('📄 Raw response:', responseData);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error);
});

req.write(data);
req.end();