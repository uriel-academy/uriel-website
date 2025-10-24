const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

async function printDoc(id) {
  const doc = await db.collection('questions').doc(id).get();
  if (!doc.exists) {
    console.log('not found', id);
    return;
  }
  console.log(JSON.stringify(doc.data(), null, 2));
}

const id = process.argv[2] || 'ict_2012_q1';
printDoc(id).then(() => admin.app().delete());
