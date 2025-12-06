// Direct Firestore update to set super admin
// This doesn't require service account credentials, just uses Application Default Credentials

const admin = require('firebase-admin');

// Initialize without credentials - will use Firebase CLI authentication
admin.initializeApp({
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();
const auth = admin.auth();

async function setSuperAdmin() {
  const email = 'studywithuriel@gmail.com';
  const uid = 'od2gYGS4k9WQwcLGg9uGjmWysEi1';
  
  try {
    console.log(`🔄 Setting super admin for ${email} (${uid})...`);
    
    // Set custom claims in Auth
    try {
      await auth.setCustomUserClaims(uid, {
        admin: true,
        superAdmin: true
      });
      console.log('✅ Set custom auth claims');
    } catch (authError) {
      console.log('⚠️  Could not set custom claims (requires service account):', authError.message);
      console.log('   Continuing with Firestore update only...');
    }
    
    // Update Firestore document
    await db.collection('users').doc(uid).set({
      email: email,
      role: 'admin',
      isSuperAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log('✅ Updated Firestore document');
    console.log('\n🎉 SUCCESS! User document updated:');
    console.log('   - role: admin');
    console.log('   - isSuperAdmin: true');
    console.log('\n📝 User should sign out and sign in again to see changes.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

setSuperAdmin();
