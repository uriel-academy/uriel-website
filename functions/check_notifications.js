const admin = require('firebase-admin');

// Initialize with project ID
admin.initializeApp({
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();

async function checkNotifications() {
  try {
    // Get user details
    const user = await admin.auth().getUserByEmail('samwilfredaddo@gmail.com');
    console.log('\n=== User Details ===');
    console.log('User ID:', user.uid);
    console.log('Email:', user.email);
    console.log('Custom Claims:', JSON.stringify(user.customClaims, null, 2));
    
    const userDoc = await db.collection('users').doc(user.uid).get();
    const userData = userDoc.data();
    console.log('Role:', userData?.role);
    console.log('School ID:', userData?.tenant?.schoolId);
    console.log('Grade:', userData?.profile?.level);
    
    // Get notifications for this user
    console.log('\n=== Notifications ===');
    const notificationsSnapshot = await db.collection('notifications')
      .where('userId', '==', user.uid)
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    console.log(`Found ${notificationsSnapshot.size} notifications`);
    
    notificationsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log('\n---');
      console.log('ID:', doc.id);
      console.log('Title:', data.title);
      console.log('Message:', data.message);
      console.log('From:', data.senderName, `(${data.senderRole})`);
      console.log('Read:', data.read);
      console.log('Timestamp:', data.timestamp?.toDate());
    });
    
    // Also check teacher details
    console.log('\n=== Teacher Details ===');
    const teacher = await admin.auth().getUserByEmail('wilfredsamaddo@gmail.com');
    console.log('Teacher ID:', teacher.uid);
    console.log('Teacher Claims:', JSON.stringify(teacher.customClaims, null, 2));
    
    const teacherDoc = await db.collection('users').doc(teacher.uid).get();
    const teacherData = teacherDoc.data();
    console.log('Teacher Role:', teacherData?.role);
    console.log('Teacher School ID:', teacherData?.tenant?.schoolId);
    console.log('Teaching Grade:', teacherData?.profile?.teachingGrade);
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkNotifications();
