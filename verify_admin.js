// Verify super admin status in Firestore
const admin = require('firebase-admin');

admin.initializeApp({
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();

async function verifyAdmin() {
  const uid = 'od2gYGS4k9WQwcLGg9uGjmWysEi1';
  
  try {
    const doc = await db.collection('users').doc(uid).get();
    
    if (doc.exists) {
      const data = doc.data();
      console.log('📄 User Document Data:');
      console.log('   Email:', data.email);
      console.log('   Role:', data.role);
      console.log('   isSuperAdmin:', data.isSuperAdmin);
      console.log('   Updated At:', data.updatedAt);
      
      if (data.role === 'admin' && data.isSuperAdmin === true) {
        console.log('\n✅ Super admin status confirmed!');
      } else {
        console.log('\n⚠️  Super admin fields not set correctly');
      }
    } else {
      console.log('❌ User document not found');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

verifyAdmin();
