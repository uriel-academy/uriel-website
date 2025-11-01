const admin = require('firebase-admin');
const path = require('path');

// Path to service account JSON in repo root
const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function inspect() {
  console.log('Inspecting classAggregates (up to 10 docs):');
  const classSnap = await db.collection('classAggregates').limit(10).get();
  if (classSnap.empty) {
    console.log('  No classAggregates documents found.');
  } else {
    classSnap.docs.forEach(d => {
      const data = d.data();
      console.log(`- id=${d.id} totalStudents=${data.totalStudents || 0} totalXP=${data.totalXP || 0} normalizedSchool=${data.normalizedSchool} normalizedClass=${data.normalizedClass}`);
    });
  }

  console.log('\nInspecting studentSummaries (up to 10 docs):');
  const studentSnap = await db.collection('studentSummaries').limit(10).get();
  if (studentSnap.empty) {
    console.log('  No studentSummaries documents found.');
  } else {
    studentSnap.docs.forEach(d => {
      const data = d.data();
      console.log(`- uid=${d.id} name=${(data.firstName||'') + ' ' + (data.lastName||'')} email=${data.email} totalXP=${data.totalXP || 0} questionsSolved=${data.questionsSolved || 0} normalizedSchool=${data.normalizedSchool} normalizedClass=${data.normalizedClass} teacherId=${data.teacherId}`);
    });
  }

  // Count totals
  const caCountSnap = await db.collection('classAggregates').count().get();
  const ssCountSnap = await db.collection('studentSummaries').count().get();
  console.log('\nTotals: classAggregates=', caCountSnap.data().count, ' studentSummaries=', ssCountSnap.data().count);

  process.exit(0);
}

inspect().catch(err => { console.error('Inspect failed', err); process.exit(2); });
