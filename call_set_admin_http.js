const https = require('https');

const data = JSON.stringify({
  data: {
    email: 'studywithuriel@gmail.com'
  }
});

const options = {
  hostname: 'us-central1-uriel-academy-41fb0.cloudfunctions.net',
  port: 443,
  path: '/setAdminRole',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

console.log('🔄 Calling setAdminRole function...');

const req = https.request(options, (res) => {
  let responseData = '';

  res.on('data', (chunk) => {
    responseData += chunk;
  });

  res.on('end', () => {
    console.log('\n✅ Response received:');
    console.log('Status:', res.statusCode);
    try {
      const parsed = JSON.parse(responseData);
      console.log(JSON.stringify(parsed, null, 2));
      
      if (parsed.result && parsed.result.success) {
        console.log('\n🎉 SUCCESS! studywithuriel@gmail.com is now a super admin!');
        console.log('📝 User should sign out and sign in again to see changes.');
      }
    } catch (e) {
      console.log('Response:', responseData);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Error:', error.message);
});

req.write(data);
req.end();
