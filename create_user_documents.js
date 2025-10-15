const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function createUserDocuments() {
  try {
    // Read users from JSON file
    const usersData = JSON.parse(fs.readFileSync('./users.json', 'utf8'));
    const users = usersData.users;

    console.log(`Found ${users.length} users to process...`);

    for (const user of users) {
      const uid = user.localId;
      const email = user.email;
      const displayName = user.displayName;
      const nameParts = displayName.split(' ');
      const firstName = nameParts[0];
      const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : '';

      console.log(`Processing user: ${email} (${uid})`);

      // Get current user document
      const userDocRef = db.collection('users').doc(uid);
      const userDoc = await userDocRef.get();

      // Prepare user data
      const userData = {
        firstName: firstName,
        lastName: lastName,
        email: email,
        class: userDoc.exists && userDoc.data().class ? userDoc.data().class : 'JHS Form 3 Student',
        profileImageUrl: user.photoUrl,
        presetAvatar: null,
        role: email === 'studywithuriel@gmail.com' ? 'super_admin' : 'student',
        entitlements: ['past', 'textbooks', 'trivia'],
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      if (!userDoc.exists) {
        userData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        await userDocRef.set(userData);
        console.log(`  ✅ Created user document for ${email}`);
      } else {
        // Update existing document with proper data
        await userDocRef.update(userData);
        console.log(`  ✅ Updated user document for ${email}`);
      }
    }

    // Also check for any other users in Firestore that might need updating
    const allUsersSnapshot = await db.collection('users').get();
    console.log(`\nChecking ${allUsersSnapshot.docs.length} total user documents...`);

    for (const userDoc of allUsersSnapshot.docs) {
      const data = userDoc.data();
      if (!data.firstName || data.firstName === 'undefined') {
        console.log(`Fixing user document: ${userDoc.id}`);

        // Try to get auth user data
        try {
          const authUser = await auth.getUser(userDoc.id);
          const displayName = authUser.displayName || '';
          const nameParts = displayName.split(' ');
          const firstName = nameParts[0] || 'Student';
          const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : '';

          await userDoc.ref.update({
            firstName: firstName,
            lastName: lastName,
            email: authUser.email || data.email || '',
            class: data.class || 'JHS Form 3 Student',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`  ✅ Fixed user document for ${authUser.email || userDoc.id}`);
        } catch (authError) {
          console.log(`  ⚠️ Could not get auth data for ${userDoc.id}, skipping`);
        }
      }
    }

    console.log('🎉 All user documents updated successfully!');

  } catch (error) {
    console.error('❌ Error updating user documents:', error);
  }
}

createUserDocuments();