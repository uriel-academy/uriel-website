// Run this in the Firebase console or a Node.js script
// Replace 'YOUR_USER_ID' with your actual Firebase Auth UID

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp({
  // Add your service account key here if running locally
});

async function setAdminRole() {
  const email = 'studywithuriel@gmail.com';
  
  try {
    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log('Found user:', userRecord.uid);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: 'super_admin',
      email: email
    });
    
    console.log('✅ Admin role set successfully!');
    console.log('Now sign out and sign in again to get the new permissions.');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

setAdminRole();