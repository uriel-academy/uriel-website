const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  try {
    const pSnap = await db.collection('passages').where('subject', '==', 'french').limit(1).get();
    if (pSnap.empty) {
      console.log('No french passages found');
      process.exit(0);
    }
    const pDoc = pSnap.docs[0];
    const p = pDoc.data();
    console.log('Passage ID:', pDoc.id);
    console.log('Title:', p.title || '(no title)');
    console.log('Year:', p.year || '(no year)');
    console.log('Section:', p.section || '(no section)');
    console.log('Content (full):');
    console.log('---');
    console.log(p.content || '(empty)');
    console.log('---\n');

    // Find up to 10 questions referencing this passage
    const qSnap = await db.collection('questions').where('passageId', '==', pDoc.id).limit(10).get();
    console.log('Linked questions count (sample limit 10):', qSnap.size);
    qSnap.docs.forEach(doc => {
      const d = doc.data();
      console.log('---');
      console.log('question id:', doc.id);
      console.log('qn:', d.questionNumber, 'text:', (d.questionText || '').slice(0,200));
      console.log('options:', d.options ? d.options.length : 0, 'correctAnswer:', d.correctAnswer || null);
    });

  } catch (e) {
    console.error('Failed', e && e.message ? e.message : e);
  }
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
