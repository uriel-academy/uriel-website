const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkStorybookFields() {
  console.log('🔍 Checking Storybook Fields...\n');
  
  try {
    const snapshot = await db.collection('storybooks').limit(1).get();
    
    if (snapshot.empty) {
      console.log('❌ No storybooks found!');
      process.exit(0);
    }
    
    const doc = snapshot.docs[0];
    const data = doc.data();
    
    console.log(`📖 Sample Document ID: ${doc.id}`);
    console.log(`\n📋 Fields present:`);
    console.log(JSON.stringify(data, null, 2));
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

checkStorybookFields();
