const https = require('https');
const fs = require('fs');

// Read service account for authentication
const serviceAccount = JSON.parse(
  fs.readFileSync('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json', 'utf8')
);

console.log('🚀 Calling backfillClassAggregates Cloud Function...');
console.log('⚠️  This may take a while as it processes all users...\n');

const postData = JSON.stringify({ data: {} });

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/backfillClassAggregates',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    console.log('📤 Response Status:', res.statusCode);
    try {
      const parsed = JSON.parse(data);
      console.log('📄 Response Body:', JSON.stringify(parsed, null, 2));
      
      if (parsed && parsed.result && parsed.result.ok) {
        console.log('\n✅ SUCCESS!');
        console.log('📊 Processed Students:', parsed.result.processedStudents);
        console.log('📚 Class Aggregates Created:', parsed.result.classAggregates);
        if (parsed.result.errors) {
          console.log('⚠️  Errors:', parsed.result.errors);
        }
      } else if (parsed && parsed.error) {
        console.error('\n❌ Error:', parsed.error.message);
        console.error('Details:', parsed.error);
      } else {
        console.log('\n⚠️  Unexpected response format');
      }
    } catch (e) {
      console.error('❌ Failed to parse response:', e.message);
      console.error('Raw data:', data);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ Request error:', e.message);
  process.exit(1);
});

req.write(postData);
req.end();
