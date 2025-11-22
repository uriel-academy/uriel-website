const admin = require('firebase-admin');
const https = require('https');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();

async function testLazyLoading() {
  console.log('🧪 Testing Lazy Loading Implementation\n');

  try {
    // Get a sample storybook from Firestore
    const snapshot = await db.collection('storybooks').limit(1).get();
    if (snapshot.empty) {
      console.log('❌ No storybooks found in Firestore');
      return;
    }

    const doc = snapshot.docs[0];
    const data = doc.data();

    console.log('📖 Testing storybook:', data.title);
    console.log('👤 Author:', data.author);
    console.log('🔗 Storage URL:', data.storageUrl);

    // Test if the storage URL is accessible
    if (!data.storageUrl) {
      console.log('❌ No storageUrl found - lazy loading will not work');
      return;
    }

    // Test HTTP HEAD request to check if file is accessible
    const url = new URL(data.storageUrl);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'HEAD'
    };

    console.log('\n🌐 Testing URL accessibility...');

    await new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        console.log('📊 Response Status:', res.statusCode);
        console.log('📄 Content-Type:', res.headers['content-type']);
        console.log('📏 Content-Length:', res.headers['content-length'], 'bytes');

        if (res.statusCode === 200) {
          console.log('✅ Storage URL is accessible!');
          console.log('✅ Lazy loading should work correctly');
        } else {
          console.log('❌ Storage URL returned status:', res.statusCode);
        }
        resolve();
      });

      req.on('error', (err) => {
        console.log('❌ Error accessing storage URL:', err.message);
        reject(err);
      });

      req.setTimeout(10000, () => {
        console.log('❌ Request timeout - URL may not be accessible');
        req.destroy();
        resolve();
      });

      req.end();
    });

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

testLazyLoading()
  .then(() => {
    console.log('\n✨ Lazy loading test completed!');
  })
  .catch(error => {
    console.error('\n💥 Test error:', error);
  });