const admin = require('firebase-admin');

// Initialize without explicit credentials (uses default Firebase credentials)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkUser() {
  try {
    const snapshot = await db.collection('users')
      .where('displayName', '==', 'Sam Addo')
      .get();
    
    if (snapshot.empty) {
      console.log('❌ User "Sam Addo" not found');
      process.exit(1);
    }
    
    snapshot.forEach(doc => {
      const data = doc.data();
      console.log('\n✅ Found User: Sam Addo');
      console.log('=====================================');
      console.log('User ID:', doc.id);
      console.log('Display Name:', data.displayName);
      console.log('Email:', data.email);
      console.log('Role:', data.role);
      console.log('School:', data.school || 'N/A');
      console.log('Class:', data.class || data.grade || 'N/A');
      
      // Check lastSeen field
      if (data.lastSeen) {
        const lastSeenDate = data.lastSeen.toDate ? data.lastSeen.toDate() : new Date(data.lastSeen);
        console.log('Last Seen:', lastSeenDate.toISOString());
        console.log('Last Seen (Local):', lastSeenDate.toLocaleString());
        
        // Calculate time ago
        const now = new Date();
        const diff = now - lastSeenDate;
        const minutes = Math.floor(diff / 60000);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);
        
        if (days > 0) {
          console.log('Time Since Last Seen:', `${days} day(s) ago`);
        } else if (hours > 0) {
          console.log('Time Since Last Seen:', `${hours} hour(s) ago`);
        } else if (minutes > 0) {
          console.log('Time Since Last Seen:', `${minutes} minute(s) ago`);
        } else {
          console.log('Time Since Last Seen:', 'Just now');
        }
      } else {
        console.log('Last Seen: ❌ Never (field not set)');
      }
      
      // Check lastLoginAt field
      if (data.lastLoginAt) {
        const lastLoginDate = data.lastLoginAt.toDate ? data.lastLoginAt.toDate() : new Date(data.lastLoginAt);
        console.log('Last Login:', lastLoginDate.toISOString());
        console.log('Last Login (Local):', lastLoginDate.toLocaleString());
      } else {
        console.log('Last Login: Never');
      }
      
      console.log('=====================================\n');
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkUser();
