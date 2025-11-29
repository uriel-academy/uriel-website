const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const userId = '9BW6UHZ1szLJ9WnkIqW5jweOP6b2';
const schoolCode = 'PRGA03AM71';

async function fixSchoolAdmin() {
  try {
    console.log('Updating user document to use correct role format...');
    
    await admin.firestore().collection('users').doc(userId).update({
      role: 'schoolAdmin', // Changed from 'school_admin' to match enum
      institutionCode: schoolCode, // Add institution code field
      institution_code: schoolCode, // Add legacy field name too
      'tenant.role': 'schoolAdmin' // Update tenant role too
    });
    
    console.log('✓ Updated user document');
    
    // Update custom claims too
    await admin.auth().setCustomUserClaims(userId, {
      role: 'schoolAdmin',
      schoolId: 'mmIq3lCx1DmkcsTri9dp'
    });
    
    console.log('✓ Updated custom claims');
    console.log('\n✅ School admin account fixed!');
    console.log('You can now log in with:');
    console.log('Email: wilfredsamaddo@gmail.com');
    console.log('Password: Qwertyz1!');
    console.log(`School Code: ${schoolCode}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  await admin.app().delete();
}

fixSchoolAdmin();
