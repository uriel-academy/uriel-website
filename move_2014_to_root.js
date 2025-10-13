const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const bucket = admin.storage().bucket();

async function moveFilesToRoot() {
  try {
    console.log('\n=== Moving 2014 files from subfolder to root ===\n');
    
    const oldQuestions = 'bece-rme questions/2014/bece_2014_questions.json';
    const oldAnswers = 'bece-rme questions/2014/bece_2014_answers.json';
    
    const newQuestions = 'bece-rme questions/bece_2014_questions.json';
    const newAnswers = 'bece-rme questions/bece_2014_answers.json';
    
    // Copy questions file
    console.log(`Copying ${oldQuestions} to ${newQuestions}...`);
    await bucket.file(oldQuestions).copy(bucket.file(newQuestions));
    console.log('✓ Questions file copied');
    
    // Copy answers file
    console.log(`Copying ${oldAnswers} to ${newAnswers}...`);
    await bucket.file(oldAnswers).copy(bucket.file(newAnswers));
    console.log('✓ Answers file copied');
    
    // Make files public
    await bucket.file(newQuestions).makePublic();
    await bucket.file(newAnswers).makePublic();
    console.log('✓ Files made public');
    
    // Delete old files
    console.log('\nDeleting old files from subfolder...');
    await bucket.file(oldQuestions).delete();
    await bucket.file(oldAnswers).delete();
    console.log('✓ Old files deleted');
    
    // Get download URLs
    const [qMetadata] = await bucket.file(newQuestions).getMetadata();
    const [aMetadata] = await bucket.file(newAnswers).getMetadata();
    
    console.log('\n=== Success! ===');
    console.log('\nNew file locations:');
    console.log(`Questions: ${newQuestions}`);
    console.log(`URL: https://storage.googleapis.com/${bucket.name}/${encodeURIComponent(newQuestions)}`);
    console.log(`\nAnswers: ${newAnswers}`);
    console.log(`URL: https://storage.googleapis.com/${bucket.name}/${encodeURIComponent(newAnswers)}`);
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

moveFilesToRoot();
