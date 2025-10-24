const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

async function deleteAllIct() {
  console.log('Querying for ICT questions...');
  const snapshot = await db.collection('questions').where('subject','==','ict').get();
  console.log('Found', snapshot.size, 'documents. Deleting in batches of 500...');
  const docs = snapshot.docs;
  let deleted = 0;
  // Firestore batch limit 500
  for (let i = 0; i < docs.length; i += 500) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + 500);
    for (const d of chunk) batch.delete(d.ref);
    await batch.commit();
    deleted += chunk.length;
    console.log('Deleted batch, total deleted so far:', deleted);
  }
  console.log('Done. Total deleted:', deleted);
  await admin.app().delete();
}

deleteAllIct().catch(e => { console.error('Fatal', e); process.exit(1); });
