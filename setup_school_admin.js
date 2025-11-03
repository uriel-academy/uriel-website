const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function setupSchoolAdmin() {
  const email = 'wilfredsamaddo@gmail.com';
  
  try {
    // Get user by email from Firebase Auth
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
      console.log('Found user in Firebase Auth:', userRecord.uid);
    } catch (error) {
      console.error('User not found in Firebase Auth:', error.message);
      console.log('\nPlease sign up first at https://uriel.academy');
      process.exit(1);
    }

    const uid = userRecord.uid;

    // Check if user doc exists
    const userDoc = await db.collection('users').doc(uid).get();
    
    const userData = {
      email: email,
      role: 'schoolAdmin',
      school: 'Ave Maria',
      firstName: 'Wilfred',
      lastName: 'Samaddo',
      displayName: 'Wilfred Samaddo',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (userDoc.exists) {
      // Update existing document
      await db.collection('users').doc(uid).update(userData);
      console.log('✅ Updated existing user to school admin');
    } else {
      // Create new document
      userData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      await db.collection('users').doc(uid).set(userData);
      console.log('✅ Created new user document as school admin');
    }

    console.log('\nUser details:');
    console.log('- Email:', email);
    console.log('- Role: schoolAdmin');
    console.log('- School: Ave Maria');
    console.log('- UID:', uid);
    console.log('\n✅ Setup complete! Please refresh your browser and you should be redirected to /school-admin');

  } catch (error) {
    console.error('Error setting up school admin:', error);
  }
  
  process.exit(0);
}

setupSchoolAdmin();
