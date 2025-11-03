const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const email = 'wilfredsamaddo@gmail.com';

async function deleteUser() {
  try {
    // 1. Get user from Auth by email
    console.log(`Looking up user with email: ${email}`);
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`Found user in Auth: ${userRecord.uid}`);
    
    // 2. Delete from Firestore
    console.log('Deleting user document from Firestore...');
    await admin.firestore().collection('users').doc(userRecord.uid).delete();
    console.log('✓ Deleted from Firestore');
    
    // 3. Delete from Firebase Auth
    console.log('Deleting user from Firebase Auth...');
    await admin.auth().deleteUser(userRecord.uid);
    console.log('✓ Deleted from Firebase Auth');
    
    console.log('\n✅ User completely deleted! You can now sign up fresh.');
    
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.log('User not found in Firebase Auth');
    } else {
      console.error('Error deleting user:', error);
    }
  }
  
  await admin.app().delete();
}

deleteUser();
