/**
 * Test Firestore Query for Textbooks
 */

require('dotenv').config();
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function testQuery() {
  console.log('\n🧪 Testing Firestore Queries...\n');
  
  try {
    // Test 1: Query with subject and status filter, ordered by year
    console.log('Test 1: Social Studies with status=published, ordered by year');
    try {
      const snapshot = await db.collection('textbooks')
        .where('subject', '==', 'Social Studies')
        .where('status', '==', 'published')
        .orderBy('year')
        .get();
      console.log(`✅ Success! Found ${snapshot.size} documents`);
      snapshot.forEach(doc => {
        console.log(`   - ${doc.id}: ${doc.data().title}`);
      });
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
      if (error.message.includes('index')) {
        console.log('   Index URL might be available in Firebase Console');
      }
    }
    
    // Test 2: Query without orderBy
    console.log('\nTest 2: Social Studies with status=published (no orderBy)');
    try {
      const snapshot = await db.collection('textbooks')
        .where('subject', '==', 'Social Studies')
        .where('status', '==', 'published')
        .get();
      console.log(`✅ Success! Found ${snapshot.size} documents`);
      snapshot.forEach(doc => {
        console.log(`   - ${doc.id}: ${doc.data().title} (${doc.data().year})`);
      });
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
    }
    
    // Test 3: Query with just subject filter
    console.log('\nTest 3: Social Studies only (no status filter)');
    try {
      const snapshot = await db.collection('textbooks')
        .where('subject', '==', 'Social Studies')
        .get();
      console.log(`✅ Success! Found ${snapshot.size} documents`);
      snapshot.forEach(doc => {
        console.log(`   - ${doc.id}: ${doc.data().title} (status: ${doc.data().status})`);
      });
    } catch (error) {
      console.log(`❌ Error: ${error.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

testQuery();
