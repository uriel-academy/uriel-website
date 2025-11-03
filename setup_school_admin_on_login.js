const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const email = 'wilfredsamaddo@gmail.com';
const schoolName = 'Ave Maria';
const firstName = 'Wilfred';
const lastName = 'Samaddo';

async function setupSchoolAdminOnFirstLogin() {
  try {
    console.log('Setting up listener for first-time Google sign-in...\n');
    console.log('Instructions:');
    console.log('1. Go to https://uriel-academy-41fb0.web.app');
    console.log('2. Sign in with Google using: ' + email);
    console.log('3. This script will automatically detect the new user and set them as schoolAdmin\n');
    console.log('Waiting for sign-in...');
    
    // Poll for new user
    const checkInterval = setInterval(async () => {
      try {
        const userRecord = await admin.auth().getUserByEmail(email);
        console.log(`\n✓ Detected sign-in! UID: ${userRecord.uid}`);
        
        // Set as school admin
        await admin.firestore().collection('users').doc(userRecord.uid).set({
          role: 'schoolAdmin',
          email: email.toLowerCase(),
          firstName: firstName,
          lastName: lastName,
          displayName: `${firstName} ${lastName}`,
          school: schoolName,
          profile: {
            firstName: firstName,
            lastName: lastName,
            email: email.toLowerCase(),
            phone: '',
          },
          settings: {
            language: ['en'],
            calmMode: false,
            notifications: {
              email: true,
              push: true,
              sms: false,
            },
          },
          badges: {
            level: 0,
            points: 0,
            streak: 0,
            earned: [],
          },
          entitlements: [],
          tenant: {
            schoolId: null,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        
        console.log('✓ Set user as schoolAdmin');
        console.log('✓ Set school to: ' + schoolName);
        console.log('\n✅ Setup complete! The page should now redirect to /school-admin');
        console.log('\nIf it doesn\'t redirect automatically:');
        console.log('1. Refresh the page');
        console.log('2. Or navigate directly to: https://uriel-academy-41fb0.web.app');
        
        clearInterval(checkInterval);
        await admin.app().delete();
        process.exit(0);
      } catch (error) {
        if (error.code !== 'auth/user-not-found') {
          console.error('Error:', error);
        }
        // User not found yet, keep waiting
      }
    }, 2000); // Check every 2 seconds
    
  } catch (error) {
    console.error('Error:', error);
    await admin.app().delete();
  }
}

setupSchoolAdminOnFirstLogin();
