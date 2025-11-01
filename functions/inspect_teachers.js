const admin = require('firebase-admin');
const path = require('path');

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  console.log('Listing teachers (up to 50)...');
  const snap = await db.collection('users').where('role', '==', 'teacher').limit(50).get();
  if (snap.empty) {
    console.log('No teacher documents found');
    process.exit(0);
  }
  for (const d of snap.docs) {
    const u = d.data() || {};
    const uid = d.id;
    console.log(`- uid=${uid} name=${u.profile?.firstName || u.firstName || ''} ${u.profile?.lastName || u.lastName || ''} email=${u.email || ''} tenant.schoolId=${u.tenant?.schoolId || null} teachingGrade=${u.teachingGrade || u.grade || null}`);
    try {
      const userRecord = await admin.auth().getUser(uid);
      console.log('  claims=', userRecord.customClaims || {});
    } catch (e) {
      console.warn('  failed to get auth record for', uid, e.message || e);
    }
  }
  process.exit(0);
}

run().catch(e=>{ console.error(e); process.exit(2); });
