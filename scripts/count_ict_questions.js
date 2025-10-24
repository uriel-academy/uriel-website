const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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
  console.error('No service account available.');
  process.exit(1);
}

const db = admin.firestore();

(async () => {
  const snapshot = await db.collection('questions').where('subject', '==', 'ict').get();
  console.log('ICT question docs count:', snapshot.size);
  if (!snapshot.empty) {
    const sample = snapshot.docs[0].data();
    console.log('Sample document id:', snapshot.docs[0].id);
    console.log(JSON.stringify(sample, null, 2));
  }
  process.exit(0);
})().catch(err => { console.error(err); process.exit(1); });
