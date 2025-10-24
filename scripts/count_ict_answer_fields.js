const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

async function main() {
  const snap = await db.collection('questions').where('subject', '==', 'ict').get();
  const total = snap.size;
  let haveCorrect = 0;
  let haveFullText = 0;
  let onlyLetter = 0;
  snap.docs.forEach(doc => {
    const d = doc.data() || {};
    if (d.correctAnswer) haveCorrect++;
    if (d.fullAnswer) {
      haveFullText++;
      const fa = String(d.fullAnswer);
      // detect if it's full text: contains a dot and a space like 'B. monitor' or more than one word
      if (!/\.|\s/.test(fa)) {
        onlyLetter++;
      }
    }
  });
  console.log('Total ICT docs:', total);
  console.log('Documents with correctAnswer:', haveCorrect);
  console.log('Documents with fullAnswer:', haveFullText);
  console.log('Documents where fullAnswer looks like only a letter:', onlyLetter);
  await admin.app().delete();
}

main().catch(e => { console.error(e); process.exit(1); });
