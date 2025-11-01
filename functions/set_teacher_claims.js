const admin = require('firebase-admin');
const path = require('path');

// Edit these values as needed
const TARGET_EMAIL = 'macroleap@gmail.com';
const SCHOOL_RAW = 'Ave Maria';
const TEACHING_GRADE = 'Form 1';

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('Looking up user by email:', TARGET_EMAIL);
  const user = await admin.auth().getUserByEmail(TARGET_EMAIL);
  console.log('Found uid=', user.uid);

  const claims = { role: 'teacher', schoolId: SCHOOL_RAW, teachingGrade: TEACHING_GRADE };
  console.log('Setting custom claims:', claims);
  await admin.auth().setCustomUserClaims(user.uid, claims);

  // Update users/{uid} doc to reflect teacher assignment
  const userRef = db.collection('users').doc(user.uid);
  const updateDoc = {
    role: 'teacher',
    'tenant.schoolId': SCHOOL_RAW,
    teachingGrade: TEACHING_GRADE,
    grade: TEACHING_GRADE,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  console.log('Updating users doc:', updateDoc);
  await userRef.set(updateDoc, { merge: true });

  console.log('Done. Teacher claims set and users doc updated.');
}

run().catch(e => { console.error('Failed:', e); process.exit(2); });
