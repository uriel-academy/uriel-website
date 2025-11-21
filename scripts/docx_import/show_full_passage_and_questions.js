const admin = require('firebase-admin');
const path = require('path');

async function run(passageId) {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  if (!passageId) {
    console.error('Usage: node show_full_passage_and_questions.js <passageId>');
    process.exit(2);
  }

  const pRef = db.collection('passages').doc(passageId);
  const pDoc = await pRef.get();
  if (!pDoc.exists) {
    console.error('Passage not found:', passageId);
    process.exit(1);
  }
  const passage = pDoc.data();
  console.log('\n=== Passage Document ===\n');
  console.log(JSON.stringify({ id: pDoc.id, ...passage }, null, 2));

  const qSnap = await db.collection('questions').where('passageId', '==', passageId).orderBy('questionNumber').limit(50).get();
  console.log('\nFound', qSnap.size, 'questions linked (showing up to 50)\n');
  for (const q of qSnap.docs) {
    console.log(JSON.stringify({ id: q.id, ...q.data() }, null, 2));
  }

  process.exit(0);
}

const id = process.argv[2];
run(id).catch(e => { console.error(e); process.exit(1); });
