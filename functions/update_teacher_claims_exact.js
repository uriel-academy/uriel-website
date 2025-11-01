const admin = require('firebase-admin');
const path = require('path');

// Target UID (found earlier) and exact schoolId value to match aggregates
const TARGET_UID = '2Uinubzgjhd9AWQQPfKOyK5D5a62';
const SCHOOL_ID_EXACT = 'ave maria school';
const TEACHING_GRADE = 'Form 1';

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('Updating custom claims for uid:', TARGET_UID);
  const claims = { role: 'teacher', schoolId: SCHOOL_ID_EXACT, teachingGrade: TEACHING_GRADE };
  await admin.auth().setCustomUserClaims(TARGET_UID, claims);
  console.log('Custom claims set:', claims);

  // Update users/{uid} doc
  const userRef = db.collection('users').doc(TARGET_UID);
  await userRef.set({ role: 'teacher', 'tenant.schoolId': SCHOOL_ID_EXACT, grade: TEACHING_GRADE, teachingGrade: TEACHING_GRADE, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  console.log('users doc updated to match schoolId and grade');
}

run().catch(e => { console.error('Failed to update claims', e); process.exit(2); });
