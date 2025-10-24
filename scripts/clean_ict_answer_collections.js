const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Prefer GOOGLE_APPLICATION_CREDENTIALS if set, otherwise try known service account files in the repo.
let initialized = false;
if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  initialized = true;
} else {
  const candidates = [
    path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
    path.join(process.cwd(), 'serviceAccount.json'),
    path.join(__dirname, '..', 'serviceAccount.json'),
    path.join(__dirname, 'serviceAccount.json'),
  ];
  const found = candidates.find(p => fs.existsSync(p));
  if (found) {
    const key = require(found);
    admin.initializeApp({ credential: admin.credential.cert(key) });
    initialized = true;
    console.log('Initialized admin SDK using service account file:', found);
  }
}
if (!initialized) {
  console.error('ERROR: No Google service account available. Set GOOGLE_APPLICATION_CREDENTIALS or place a service account JSON in the repo.');
  process.exit(1);
}

const db = admin.firestore();

function chunk(arr, n) {
  const res = [];
  for (let i = 0; i < arr.length; i += n) res.push(arr.slice(i, i + n));
  return res;
}

(async () => {
  console.log('Listing root collections...');
  const cols = await db.listCollections();
  const candidates = cols.map(c => c.id).filter(id => /bece_ict.*answers/i.test(id) || id === 'bece_ict_answers');
  if (!candidates.length) {
    console.log('No ICT answer-like collections found. Nothing to delete.');
    process.exit(0);
  }
  console.log('Found answer collections to clean:', candidates);

  for (const colId of candidates) {
    const colRef = db.collection(colId);
    console.log(`Querying documents in collection '${colId}'...`);
    const snapshot = await colRef.get();
    if (snapshot.empty) {
      console.log(`Collection '${colId}' is empty.`);
      continue;
    }
    const docs = snapshot.docs;
    console.log(`Deleting ${docs.length} documents from '${colId}' in batches...`);
    const batches = chunk(docs, 450);
    let deleted = 0;
    for (const batchDocs of batches) {
      const batch = db.batch();
      batchDocs.forEach(d => batch.delete(d.ref));
      await batch.commit();
      deleted += batchDocs.length;
      console.log(`Deleted batch, total deleted so far in '${colId}': ${deleted}`);
    }
    console.log(`Finished deleting ${deleted} docs from collection '${colId}'.`);
  }

  console.log('Cleaning complete.');
  process.exit(0);
})().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
