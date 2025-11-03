const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createIndex() {
  try {
    console.log('Testing if index is needed by running the query...');
    
    // Try to run the actual query that needs the index
    const testQuery = db.collection('users')
      .where('role', '==', 'student')
      .where('school', '==', 'Ave Maria')
      .orderBy('firstName')
      .limit(1);
    
    const result = await testQuery.get();
    console.log('Query succeeded! Found', result.size, 'students');
    console.log('Index already exists or query works without it.');
  } catch (error) {
    if (error.message && error.message.includes('index')) {
      console.log('\nIndex is required. Error message:');
      console.log(error.message);
      
      // Extract the index creation URL from the error
      const urlMatch = error.message.match(/https:\/\/[^\s]+/);
      if (urlMatch) {
        console.log('\n CLICK THIS LINK TO CREATE THE INDEX:');
        console.log(urlMatch[0]);
        console.log('\nAfter clicking, the index will build in 1-5 minutes.');
      }
    } else {
      console.error('Unexpected error:', error.message);
    }
  }
  process.exit(0);
}

createIndex();
