// Simple HTTPS POST to callable function endpoint
const https = require('https');

const postData = JSON.stringify({ data: {} });

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/importICTQuestions',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('🚀 Calling importICTQuestions Cloud Function...');

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log('📤 Response Status:', res.statusCode);
    try {
      const parsed = JSON.parse(data);
      console.log('📄 Response Body:', JSON.stringify(parsed, null, 2));
      if (parsed && parsed.result && parsed.result.success) {
        console.log('🎉 SUCCESS:', parsed.result.message);
      } else if (parsed && parsed.error) {
        console.error('❌ Error:', parsed.error);
      } else if (parsed && parsed.success) {
        console.log('🎉 SUCCESS:', parsed.message);
      } else {
        console.log('❌ Unexpected response shape');
      }
    } catch (e) {
      console.error('❌ Failed to parse response:', e, data);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ Request error:', e);
});

req.write(postData);
req.end();
