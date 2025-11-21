const admin = require('firebase-admin');
const path = require('path');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  try {
    const snapshot = await db.collection('passages').where('subject', '==', 'french').limit(10).get();
    console.log('Found', snapshot.size, 'french passages');
    snapshot.docs.forEach(doc => {
      const d = doc.data();
      console.log('---');
      console.log('id:', doc.id);
      console.log('title:', d.title || '(no title)');
      console.log('year:', d.year || '(no year)');
      console.log('section:', d.section || '(no section)');
      const preview = (d.content || '').replace(/\s+/g, ' ').trim().slice(0, 200);
      console.log('content-preview:', preview + (preview.length >= 200 ? '...' : ''));
    });
  } catch (e) {
    console.error('Query failed', e && e.message ? e.message : e);
  }
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
