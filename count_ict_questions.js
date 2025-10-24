const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

async function countIct() {
  try {
    const db = admin.firestore();
    const snap = await db.collection('questions').where('subject', '==', 'ict').get();
    console.log('ICT documents count:', snap.size);
    // Print up to 10 doc ids
    snap.docs.slice(0, 10).forEach(d => console.log(d.id));
  } catch (e) {
    console.error('Error querying Firestore:', e);
  } finally {
    admin.app().delete();
  }
}

countIct();
