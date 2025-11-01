const admin = require('firebase-admin');
const path = require('path');

// Edit these if needed
const TARGET_EMAIL = 'macroleap@gmail.com';
const SCHOOL_RAW = 'Ave Maria';
const TEACHING_GRADE = 'Form 1';

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('Looking up user by email:', TARGET_EMAIL);
  const userRecord = await admin.auth().getUserByEmail(TARGET_EMAIL);
  const uid = userRecord.uid;
  console.log('Found uid=', uid, 'displayName=', userRecord.displayName);

  // Derive first/last name from displayName if available
  let firstName = '';
  let lastName = '';
  if (userRecord.displayName) {
    const parts = userRecord.displayName.split(' ');
    firstName = parts[0];
    lastName = parts.slice(1).join(' ');
  }

  const docRef = db.collection('users').doc(uid);
  const updateDoc = {
    role: 'teacher',
    email: TARGET_EMAIL,
    schoolName: SCHOOL_RAW,
    school: SCHOOL_RAW,
    teachingGrade: TEACHING_GRADE,
    grade: TEACHING_GRADE,
    firstName: firstName || undefined,
    lastName: lastName || undefined,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  console.log('Updating users doc with:', updateDoc);
  await docRef.set(updateDoc, { merge: true });

  // Ensure custom claims are set too
  const desiredClaims = { role: 'teacher', schoolId: SCHOOL_RAW.toLowerCase(), teachingGrade: TEACHING_GRADE };
  console.log('Setting custom claims:', desiredClaims);
  await admin.auth().setCustomUserClaims(uid, desiredClaims);

  console.log('Done. Please ask the teacher to sign out and sign back in to refresh token.');
}

run().catch(e => { console.error('Failed:', e); process.exit(2); });
