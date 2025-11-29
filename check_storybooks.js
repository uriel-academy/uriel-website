const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkStorybooks() {
  console.log('📚 Checking Storybooks in Firestore...\n');
  
  try {
    const snapshot = await db.collection('storybooks').get();
    
    console.log(`Total documents: ${snapshot.size}\n`);
    
    if (snapshot.empty) {
      console.log('❌ No storybooks found in Firestore!');
      console.log('Run upload_storybooks.js to upload them.');
      process.exit(0);
    }
    
    let activeCount = 0;
    let inactiveCount = 0;
    
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.isActive) {
        activeCount++;
      } else {
        inactiveCount++;
      }
    });
    
    console.log(`📊 Summary:`);
    console.log(`   ✅ Active: ${activeCount}`);
    console.log(`   ⏸️  Inactive: ${inactiveCount}`);
    console.log(`   📖 Total: ${snapshot.size}`);
    
    console.log('\n📋 Sample storybooks:');
    let count = 0;
    snapshot.forEach(doc => {
      if (count < 5) {
        const data = doc.data();
        console.log(`   - ${data.title} by ${data.author} (${data.isActive ? 'Active' : 'Inactive'})`);
        count++;
      }
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

checkStorybooks();
