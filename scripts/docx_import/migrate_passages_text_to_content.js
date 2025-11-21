const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  console.log('Scanning passages for `text` field to migrate to `content`...');
  const snapshot = await db.collection('passages').where('text', '!=', null).get();
  console.log('Found', snapshot.size, 'passage docs with `text` field (to migrate)');

  if (snapshot.empty) {
    console.log('Nothing to migrate.');
    process.exit(0);
  }

  const batchSize = 50;
  let processed = 0;

  for (let i = 0; i < snapshot.docs.length; i += batchSize) {
    const batch = db.batch();
    const chunk = snapshot.docs.slice(i, i + batchSize);
    for (const doc of chunk) {
      const data = doc.data();
      const text = data.text || '';
      const titlePreview = text.split('\n').map(s => s.trim()).find(s => s.length > 10) || 'Passage';
      const payload = {
        content: text,
        title: titlePreview.length > 80 ? titlePreview.slice(0, 80) + '...' : titlePreview,
        section: data.section || 'COMPREHENSION',
        year: data.year || '',
        isActive: data.isActive === undefined ? true : data.isActive,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      // unset 'text' and set 'content' + metadata
      batch.update(doc.ref, Object.assign({}, payload, { text: admin.firestore.FieldValue.delete() }));
      processed++;
    }
    await batch.commit();
    console.log('Migrated', Math.min(i + batchSize, snapshot.docs.length), '/', snapshot.docs.length);
  }

  console.log('Migration complete. Total migrated:', processed);
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
