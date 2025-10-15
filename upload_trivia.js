const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'gs://uriel-academy-41fb0.appspot.com'
});

const bucket = admin.storage().bucket();

async function ensureBucketExists() {
  try {
    console.log('🔍 Checking if storage bucket exists...');
    const [exists] = await bucket.exists();
    if (!exists) {
      console.log('❌ Storage bucket does not exist.');
      console.log('📋 To enable Firebase Storage:');
      console.log('   1. Go to Firebase Console: https://console.firebase.google.com/');
      console.log('   2. Select project: uriel-academy-41fb0');
      console.log('   3. Go to Storage section');
      console.log('   4. Click "Get started" to enable Cloud Storage');
      console.log('   5. Choose "Start in test mode" or configure security rules');
      console.log('   6. Re-run this script');
      throw new Error('Firebase Storage bucket not found. Please enable Storage in Firebase Console first.');
    } else {
      console.log('✅ Bucket exists and is accessible');
    }
  } catch (error) {
    console.error('❌ Error checking bucket:', error.message);
    throw error;
  }
}

async function uploadTriviaFiles() {
  // Ensure bucket exists
  await ensureBucketExists();

  const triviaDir = path.join(__dirname, 'assets', 'trivia');
  const files = fs.readdirSync(triviaDir);

  console.log(`Found ${files.length} trivia files to upload...`);

  let successCount = 0;
  let errorCount = 0;

  for (const file of files) {
    try {
      const filePath = path.join(triviaDir, file);
      const fileStats = fs.statSync(filePath);

      // Skip if not a file
      if (!fileStats.isFile()) continue;

      // Only process JSON files
      if (!file.endsWith('.json')) {
        console.log(`⏭️  Skipping non-JSON file: ${file}`);
        continue;
      }

      console.log(`\n📤 Uploading: ${file}`);

      // Upload to Firebase Storage
      const destination = `trivia/${file}`;
      await bucket.upload(filePath, {
        destination: destination,
        metadata: {
          contentType: 'application/json',
          metadata: {
            originalName: file,
            uploadedAt: new Date().toISOString(),
          }
        }
      });

      // Make the file publicly readable
      const fileRef = bucket.file(destination);
      await fileRef.makePublic();

      console.log(`✅ Success: ${file}`);
      successCount++;

    } catch (error) {
      console.error(`❌ Error uploading ${file}:`, error.message);
      errorCount++;
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`📊 Upload Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${errorCount}`);
  console.log(`   📄 Total: ${successCount + errorCount}`);
  console.log('='.repeat(60));
}

// Run the upload
uploadTriviaFiles()
  .then(() => {
    console.log('\n✨ All trivia files uploaded successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });