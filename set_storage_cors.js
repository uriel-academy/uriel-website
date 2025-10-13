const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const bucket = admin.storage().bucket();

async function setCORS() {
  console.log('🔧 Setting CORS configuration for Storage bucket...\n');
  
  try {
    // Set CORS configuration
    await bucket.setCorsConfiguration([
      {
        origin: ['*'],
        method: ['GET', 'HEAD'],
        maxAgeSeconds: 3600,
      }
    ]);
    
    console.log('✅ CORS configuration applied successfully!');
    console.log('📝 Configuration:');
    console.log('   - Origin: * (all domains)');
    console.log('   - Methods: GET, HEAD');
    console.log('   - Max Age: 3600 seconds (1 hour)');
    console.log('\n🌐 Images should now be accessible from your web app!');
    
  } catch (error) {
    console.error('❌ Error setting CORS:', error.message);
    console.log('\n💡 Alternative: Set CORS using Google Cloud Console:');
    console.log('   1. Go to: https://console.cloud.google.com/storage/browser');
    console.log('   2. Select your bucket: uriel-academy-41fb0.firebasestorage.app');
    console.log('   3. Click "Permissions" tab');
    console.log('   4. Add "allUsers" with role "Storage Object Viewer"');
    console.log('\n   OR use gsutil (requires Google Cloud SDK):');
    console.log('   gsutil cors set cors.json gs://uriel-academy-41fb0.firebasestorage.app');
  }
  
  process.exit(0);
}

setCORS();
