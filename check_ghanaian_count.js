// check_ghanaian_count.js
// Usage: node check_ghanaian_count.js --serviceAccount=<path-to-service-account-json>
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';
(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    const snap = await db.collection('questions').where('subject', '==', 'ghanaianLanguage').limit(1).get();
    if (snap.empty) {
      console.log('No Ghanaian language questions found (subject == "ghanaianLanguage").');
    } else {
      // Count samples (not efficient for very large collections)
      const q = await db.collection('questions').where('subject', '==', 'ghanaianLanguage').get();
      console.log('Ghanaian language questions count:', q.size);
    }
    process.exit(0);
  } catch (e) {
    console.error('Error checking questions:', e);
    process.exit(1);
  }
})();
