const https = require('https');

const imageUrl = 'https://storage.googleapis.com/uriel-academy-41fb0.firebasestorage.app/leaderboard_ranks/rank_1.png';

console.log('🔍 Testing image accessibility...\n');
console.log(`URL: ${imageUrl}\n`);

https.get(imageUrl, (res) => {
  console.log('✅ Response received:');
  console.log(`   Status: ${res.statusCode} ${res.statusMessage}`);
  console.log(`   Headers:`);
  console.log(`   - Content-Type: ${res.headers['content-type']}`);
  console.log(`   - Content-Length: ${res.headers['content-length']}`);
  console.log(`   - Access-Control-Allow-Origin: ${res.headers['access-control-allow-origin'] || 'NOT SET'}`);
  console.log(`   - Cache-Control: ${res.headers['cache-control'] || 'NOT SET'}`);
  
  if (res.statusCode === 200) {
    console.log('\n✅ Image is accessible!');
  } else {
    console.log('\n⚠️ Unexpected status code');
  }
  
  if (res.headers['access-control-allow-origin']) {
    console.log('✅ CORS header is present');
  } else {
    console.log('❌ CORS header is missing - this will cause browser errors');
  }
}).on('error', (err) => {
  console.error('❌ Error:', err.message);
}).end();
