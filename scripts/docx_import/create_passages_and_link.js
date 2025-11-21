const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: sa.project_id + '.appspot.com' });
  const db = admin.firestore();

  console.log('Querying French questions with inline passages...');
  const snapshot = await db.collection('questions').where('subject', '==', 'french').where('examType', '==', 'bece').get();
  if (snapshot.empty) {
    console.log('No french questions found.');
    process.exit(0);
  }

  // Collect questions that have a non-empty `passage` field
  const withPassage = [];
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    if (data.passage && typeof data.passage === 'string' && data.passage.trim().length > 40) {
      withPassage.push({ id: doc.id, ref: doc.ref, passage: data.passage.trim() });
    }
  });

  if (withPassage.length === 0) {
    console.log('No French questions with inline passage text found.');
    process.exit(0);
  }

  console.log('Found', withPassage.length, 'questions with passages. Grouping identical passages...');

  // Group passages by text (dedupe)
  const map = new Map();
  for (const item of withPassage) {
    const key = item.passage;
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }

  console.log('Unique passages:', map.size);

  // Create passage docs and update questions to reference them
  for (const [text, items] of map.entries()) {
    try {
      // Create passage with the fields the app expects: 'content' and 'title'
      const titlePreview = text.split('\n').map(s => s.trim()).find(s => s.length > 10) || 'Passage';
      const passagePayload = {
        content: text,
        title: titlePreview.length > 80 ? titlePreview.slice(0, 80) + '...' : titlePreview,
        subject: 'french',
        examType: 'bece',
        year: '',
        section: 'COMPREHENSION',
        questionRange: [],
        createdBy: 'docx_import',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      };
      const passageDoc = await db.collection('passages').add(passagePayload);
      console.log('  Created passage', passageDoc.id, 'for', items.length, 'questions');

      // Update all questions that belong to this passage
      const batch = db.batch();
      items.forEach(it => {
        batch.update(it.ref, { passageId: passageDoc.id, passage: admin.firestore.FieldValue.delete(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
      await batch.commit();
      console.log('  Linked', items.length, 'questions to passage', passageDoc.id);
    } catch (e) {
      console.error('Failed to create/link passage', e && e.message ? e.message : e);
    }
  }

  console.log('Passage creation and linking complete.');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
