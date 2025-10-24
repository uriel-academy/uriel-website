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
  }
}
if (!initialized) {
  console.error('No service account available.');
  process.exit(1);
}

const db = admin.firestore();

(async () => {
  const cols = await db.listCollections();
  console.log('Root collections:');
  cols.forEach(c => console.log(' -', c.id));
  process.exit(0);
})();
