const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const passagesSnap = await db.collection('passages').where('subject', '==', 'french').get();
  console.log('Found', passagesSnap.size, 'french passages to inspect');

  for (const pDoc of passagesSnap.docs) {
    try {
      const p = pDoc.data();
      // find questions linked to this passage
      const qSnap = await db.collection('questions').where('passageId', '==', pDoc.id).get();
      if (qSnap.empty) {
        console.log('No linked questions for', pDoc.id);
        continue;
      }
      const qNums = [];
      const years = new Set();
      qSnap.docs.forEach(d => {
        const data = d.data();
        if (typeof data.questionNumber === 'number') qNums.push(data.questionNumber);
        if (data.year) years.add(data.year.toString());
      });
      qNums.sort((a,b) => a-b);
      const questionRange = qNums.length ? [qNums[0], qNums[qNums.length-1]] : [];
      const year = years.size === 1 ? Array.from(years)[0] : '';

      const updatePayload = {
        questionRange,
        year,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await pDoc.ref.update(updatePayload);
      console.log('Updated passage', pDoc.id, '-> questionRange:', questionRange, 'year:', year || '(mixed)');
    } catch (e) {
      console.error('Failed to update passage', pDoc.id, e && e.message ? e.message : e);
    }
  }

  console.log('Done.');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
