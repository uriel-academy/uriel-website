const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const keyPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!fs.existsSync(keyPath)) { console.error('Service account key not found:', keyPath); process.exit(1); }

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const auth = admin.auth();
const db = admin.firestore();

(async () => {
  try {
    const email = 'test-rme+1@uriel.test';
    const password = 'TestRme123!';

    // Check if user exists by email
    let userRecord;
    try { userRecord = await auth.getUserByEmail(email); } catch (e) { userRecord = null; }

    if (!userRecord) {
      userRecord = await auth.createUser({ email, password, displayName: 'RME Tester' });
      console.log('Created user', userRecord.uid);
    } else {
      console.log('User already exists', userRecord.uid);
      // Update password to known value
      await auth.updateUser(userRecord.uid, { password });
      console.log('Password reset for existing user');
    }

    // Set entitlements in Firestore users doc to include 'past'
    await db.collection('users').doc(userRecord.uid).set({
      firstName: 'RME',
      lastName: 'Tester',
      entitlements: ['past'],
      role: 'student'
    }, { merge: true });

    console.log('Set entitlements for user, you can sign in with', email, password);
    process.exit(0);
  } catch (err) {
    console.error('Error creating test user:', err);
    process.exit(2);
  }
})();
