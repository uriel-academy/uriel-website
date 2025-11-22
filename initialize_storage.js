const admin = require('firebase-admin');
const { Storage } = require('@google-cloud/storage');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.appspot.com'
});

// Initialize Google Cloud Storage client
const storage = new Storage({
  projectId: 'uriel-academy-41fb0',
  credentials: serviceAccount
});

const bucketName = 'uriel-academy-41fb0.appspot.com';

async function initializeStorage() {
  try {
    console.log('🔍 Checking Firebase Storage bucket...');

    // Try to get the bucket
    const bucket = storage.bucket(bucketName);
    const [exists] = await bucket.exists();

    if (exists) {
      console.log('✅ Storage bucket already exists:', bucketName);
      return;
    }

    console.log('📦 Storage bucket does not exist. Creating...');

    // Create the bucket
    await storage.createBucket(bucketName, {
      location: 'US-CENTRAL1',
      storageClass: 'STANDARD',
    });

    console.log('✅ Storage bucket created successfully:', bucketName);

    // Set CORS policy for web access
    const corsConfig = [{
      origin: ['*'],
      method: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      responseHeader: ['Content-Type', 'Authorization', 'Content-Length'],
      maxAgeSeconds: 3600
    }];

    await bucket.setCorsConfiguration(corsConfig);
    console.log('✅ CORS configuration set');

  } catch (error) {
    console.error('❌ Error with storage bucket:', error.message);

    // If bucket creation fails, try to check if it was created by Firebase
    try {
      const bucket = storage.bucket(bucketName);
      const [exists] = await bucket.exists();
      if (exists) {
        console.log('✅ Storage bucket exists (created by Firebase):', bucketName);
        return;
      }
    } catch (checkError) {
      console.error('❌ Error checking bucket existence:', checkError.message);
    }

    process.exit(1);
  }
}

initializeStorage()
  .then(() => {
    console.log('\n✨ Storage initialization complete!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });