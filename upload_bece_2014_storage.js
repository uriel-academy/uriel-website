const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const bucket = admin.storage().bucket();

console.log('📤 Starting BECE 2014 RME Upload to Firebase Storage...\n');

async function uploadToStorage() {
  try {
    const questionsPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', 'bece_2014_questions.json');
    const answersPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', 'bece_2014_answers.json');
    
    // Define storage paths (following existing pattern)
    const storageQuestionsPath = 'bece-rme questions/2014/bece_2014_questions.json';
    const storageAnswersPath = 'bece-rme questions/2014/bece_2014_answers.json';
    
    console.log('📁 Uploading questions file...');
    await bucket.upload(questionsPath, {
      destination: storageQuestionsPath,
      metadata: {
        contentType: 'application/json',
        metadata: {
          year: '2014',
          subject: 'RME',
          examType: 'BECE',
          uploadedAt: new Date().toISOString()
        }
      },
      public: true // Make file publicly accessible
    });
    
    console.log('✅ Questions file uploaded successfully');
    console.log(`   Path: ${storageQuestionsPath}`);
    
    console.log('\n📁 Uploading answers file...');
    await bucket.upload(answersPath, {
      destination: storageAnswersPath,
      metadata: {
        contentType: 'application/json',
        metadata: {
          year: '2014',
          subject: 'RME',
          examType: 'BECE',
          uploadedAt: new Date().toISOString()
        }
      },
      public: true // Make file publicly accessible
    });
    
    console.log('✅ Answers file uploaded successfully');
    console.log(`   Path: ${storageAnswersPath}`);
    
    // Get download URLs
    const [questionsFile] = await bucket.file(storageQuestionsPath).get();
    const [answersFile] = await bucket.file(storageAnswersPath).get();
    
    // Make files publicly accessible
    await questionsFile.makePublic();
    await answersFile.makePublic();
    
    const questionsUrl = `https://storage.googleapis.com/${bucket.name}/${storageQuestionsPath}`;
    const answersUrl = `https://storage.googleapis.com/${bucket.name}/${storageAnswersPath}`;
    
    console.log('\n🔗 Download URLs:');
    console.log(`   Questions: ${questionsUrl}`);
    console.log(`   Answers: ${answersUrl}`);
    
    console.log('\n✨ Upload completed successfully!');
    console.log('\n📱 The files are now accessible in:');
    console.log('   ✓ RME Past Questions Page');
    console.log('   ✓ Firebase Storage Console');
    
    // List all files in the bece-rme questions folder to verify
    console.log('\n📊 Verifying storage structure...');
    const [files] = await bucket.getFiles({ prefix: 'bece-rme questions/' });
    const years = new Set();
    files.forEach(file => {
      const match = file.name.match(/bece-rme questions\/(\d{4})\//);
      if (match) {
        years.add(match[1]);
      }
    });
    
    console.log(`✓ Total years available: ${Array.from(years).sort().join(', ')}`);
    
  } catch (error) {
    console.error('❌ Error uploading files:', error);
    throw error;
  }
}

async function main() {
  try {
    await uploadToStorage();
    console.log('\n🎉 Upload completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Upload failed:', error);
    process.exit(1);
  }
}

// Run the upload
main();
