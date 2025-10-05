const admin = require('firebase-admin');
const path = require('path');

const keyPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!require('fs').existsSync(keyPath)) {
  console.error('Service account key not found at', keyPath);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(keyPath))
});

const db = admin.firestore();

(async () => {
  try {
    const snapshot = await db.collection('questions').where('subject', '==', 'religiousMoralEducation').get();
    console.log('Found', snapshot.size, 'RME documents.');
    let i = 0;
    snapshot.forEach(doc => { if (i < 10) console.log('-', doc.id); i++; });
    process.exit(0);
  } catch (err) {
    console.error('Error querying Firestore:', err);
    process.exit(2);
  }
})();
