// Script to import Social Studies questions using Cloud Function
const https = require('https');

const data = JSON.stringify({
  data: {}
});

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/importSocialStudiesQuestions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length,
    'Authorization': 'Bearer ' + process.env.FIREBASE_TOKEN // You'll need to set this
  }
};

console.log('🚀 Starting Social Studies questions import...');
console.log('⚠️  This may take several minutes...\n');

const req = https.request(options, (res) => {
  let responseData = '';
  
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('\n📤 Response Status:', res.statusCode);
    
    try {
      const result = JSON.parse(responseData);
      if (result.result && result.result.success) {
        console.log('🎉 SUCCESS!');
        console.log('📝 Message:', result.result.message);
        console.log('📊 Questions Imported:', result.result.questionsImported);
      } else if (result.error) {
        console.log('❌ Error:', result.error.message || result.error);
      } else {
        console.log('📄 Response:', result);
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
