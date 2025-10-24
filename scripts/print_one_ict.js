const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

async function printOne() {
  const db = admin.firestore();
  const id = 'ict_2011_q1';
  try {
    const doc = await db.collection('questions').doc(id).get();
    if (!doc.exists) {
      console.log('Document not found:', id);
      return;
    }
    console.log('Document:', id);
    console.log(JSON.stringify(doc.data(), null, 2));
  } catch (e) {
    console.error('Error fetching doc:', e);
  } finally {
    await admin.app().delete();
  }
}

printOne();
