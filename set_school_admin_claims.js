const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();

async function setSchoolAdminClaims() {
  const email = 'wilfredsamaddo@gmail.com';
  
  try {
    // Get user by email
    const userRecord = await auth.getUserByEmail(email);
    console.log('Found user:', userRecord.uid);
    
    // Set custom claims
    await auth.setCustomUserClaims(userRecord.uid, {
      role: 'school_admin',
      school: 'Ave Maria'
    });
    
    console.log('✅ Custom claims set successfully!');
    console.log('   Role: school_admin');
    console.log('   School: Ave Maria');
    console.log('\n⚠️  User must sign out and sign back in for claims to take effect');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

setSchoolAdminClaims();
