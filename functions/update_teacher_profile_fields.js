const admin = require('firebase-admin');
const path = require('path');

const TARGET_UID = '2Uinubzgjhd9AWQQPfKOyK5D5a62';
const SCHOOL_PRETTY = 'Ave Maria';
const SCHOOL_ID_EXACT = 'ave maria school';
const TEACHING_GRADE = 'Form 1';

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('Updating users doc for teacher:', TARGET_UID);
  const userRef = db.collection('users').doc(TARGET_UID);
  await userRef.set({
    school: SCHOOL_PRETTY,
    schoolName: SCHOOL_PRETTY,
    'tenant.schoolId': SCHOOL_ID_EXACT,
    teachingGrade: TEACHING_GRADE,
    grade: TEACHING_GRADE,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
  console.log('Updated users doc with school and grade fields');
}

run().catch(e => { console.error('Failed', e); process.exit(2); });
