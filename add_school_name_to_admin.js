const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addSchoolNameToAdmin() {
  try {
    const adminUserId = '9BW6UHZ1szLJ9WnkIqW5jweOP6b2';
    const schoolName = 'Ave Maria';

    console.log(`🔍 Updating admin user: ${adminUserId}`);
    console.log(`📝 Setting schoolName: "${schoolName}"`);

    // Get current admin data
    const adminDoc = await db.collection('users').doc(adminUserId).get();
    
    if (!adminDoc.exists) {
      console.error('❌ Admin user not found!');
      return;
    }

    const currentData = adminDoc.data();
    console.log('📊 Current admin data:');
    console.log(`   - Name: ${currentData.name || 'N/A'}`);
    console.log(`   - Email: ${currentData.email || 'N/A'}`);
    console.log(`   - Role: ${currentData.role || 'N/A'}`);
    console.log(`   - Current schoolName: ${currentData.schoolName || 'null'}`);

    // Update with schoolName field
    await db.collection('users').doc(adminUserId).update({
      schoolName: schoolName
    });

    console.log('✅ Successfully added schoolName field!');
    
    // Verify the update
    const updatedDoc = await db.collection('users').doc(adminUserId).get();
    const updatedData = updatedDoc.data();
    console.log(`✅ Verified - schoolName is now: "${updatedData.schoolName}"`);

    console.log('\n🎉 Admin account updated successfully!');
    console.log('🔄 Refresh the school admin dashboard to see grade analytics.');

  } catch (error) {
    console.error('❌ Error updating admin:', error);
  } finally {
    process.exit(0);
  }
}

addSchoolNameToAdmin();
