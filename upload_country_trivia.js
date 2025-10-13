const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
try {
  admin.app();
} catch (e) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
  });
}

const bucket = admin.storage().bucket();

console.log('📤 Uploading Country Trivia to Firebase Storage...\n');

async function uploadTriviaFiles() {
  try {
    const triviaFiles = [
      'trivia_index.json',
      'country_questions.json',
      'country_answers.json'
    ];
    
    for (const fileName of triviaFiles) {
      const localPath = path.join(__dirname, 'assets', 'trivia', fileName);
      const storagePath = `trivia/${fileName}`;
      
      console.log(`📁 Uploading ${fileName}...`);
      
      // Check if file exists
      if (!fs.existsSync(localPath)) {
        console.log(`⚠️  File not found: ${localPath}`);
        continue;
      }
      
      await bucket.upload(localPath, {
        destination: storagePath,
        metadata: {
          contentType: 'application/json',
          metadata: {
            category: 'trivia',
            uploadedAt: new Date().toISOString()
          }
        },
        public: true
      });
      
      console.log(`✅ ${fileName} uploaded successfully`);
      console.log(`   Path: ${storagePath}`);
      
      // Make file publicly accessible
      const file = bucket.file(storagePath);
      await file.makePublic();
      
      const url = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
      console.log(`   URL: ${url}\n`);
    }
    
    // Verify all trivia files
    console.log('📊 Verifying trivia storage structure...');
    const [files] = await bucket.getFiles({ prefix: 'trivia/' });
    
    console.log(`✓ Total trivia files in storage: ${files.length}`);
    console.log('\n📋 Available trivia files:');
    files.forEach(file => {
      console.log(`   - ${file.name}`);
    });
    
    console.log('\n✨ Country trivia is now available!');
    console.log('   ✓ Accessible in Trivia Page');
    console.log('   ✓ Firebase Storage Console');
    
  } catch (error) {
    console.error('❌ Error uploading files:', error);
    throw error;
  }
}

async function main() {
  try {
    await uploadTriviaFiles();
    console.log('\n🎉 Upload completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Upload failed:', error);
    process.exit(1);
  }
}

main();
