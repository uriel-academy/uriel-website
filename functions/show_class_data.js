const admin = require('firebase-admin');
const path = require('path');

const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  const classId = 'ave_maria_form_1';
  console.log('Reading classAggregates doc:', classId);
  const cdoc = await db.collection('classAggregates').doc(classId).get();
  if (!cdoc.exists) {
    console.log('classAggregates doc not found');
  } else {
    console.log('classAggregates:', JSON.stringify(cdoc.data(), null, 2));
  }

  console.log('\nQuerying studentSummaries for normalizedSchool=ave_maria AND normalizedClass=form_1');
  const qs = await db.collection('studentSummaries').where('normalizedSchool', '==', 'ave_maria').where('normalizedClass', '==', 'form_1').get();
  console.log('Found', qs.size, 'studentSummaries');
  for (const d of qs.docs) {
    console.log('-', d.id, JSON.stringify(d.data()));
  }
}

run().catch(e=>{ console.error(e); process.exit(2); });
