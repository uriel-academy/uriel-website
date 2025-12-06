const admin = require('firebase-admin');

// Check if service account file exists
const fs = require('fs');
const serviceAccountPath = './uriel-academy-41fb0-firebase-adminsdk-oljcz-18b3a4fc6a.json';

if (!fs.existsSync(serviceAccountPath)) {
  console.log('❌ Service account file not found. Trying alternative approach...');
  
  // Initialize with project ID only (will use default credentials if available)
  admin.initializeApp({
    projectId: 'uriel-academy-41fb0'
  });
} else {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function setAdminRole() {
  try {
    const email = 'studywithuriel@gmail.com';
    
    console.log(`🔍 Looking for user: ${email}`);
    
    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`✅ Found user: ${userRecord.uid}`);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, { 
      admin: true,
      superAdmin: true,
      email: email 
    });
    console.log('✅ Set custom claims (superAdmin: true)');
    
    // Update user document in Firestore with both isSuperAdmin flag and role
    const db = admin.firestore();
    await db.collection('users').doc(userRecord.uid).set({
      role: 'admin',
      isSuperAdmin: true,
      email: email,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    console.log('✅ Updated user document in Firestore (role: admin, isSuperAdmin: true)');
    
    console.log(`🎉 SUCCESS: ${email} now has super_admin privileges!`);
    console.log('📝 Note: User should sign out and sign in again to access admin features.');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'auth/user-not-found') {
      console.log('💡 The user needs to sign up first before we can grant admin privileges.');
    }
  }
  
  process.exit(0);
}

setAdminRole();