const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const admin = require('firebase-admin');
const path = require('path');

(async () => {
  try {
    const url = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttpLegacy';
    const message = `E2E smoke test at ${new Date().toISOString()}`;
    console.log('POSTing to', url, 'message:', message);
    const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ message }) });
    const text = await res.text();
    console.log('HTTP STATUS', res.status);
    let body;
    try { body = JSON.parse(text); } catch (e) { body = text; }
    console.log('RESPONSE BODY:', body);

    // If sessionId available, query Firestore
    const sessionId = (body && body.sessionId) ? body.sessionId : null;

    // Initialize admin with service account
    const keyPath = path.join(__dirname, 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
    console.log('Using service account:', keyPath);
    admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
    const db = admin.firestore();

    if (sessionId) {
      console.log('Querying messages for sessionId:', sessionId);
      const snaps = await db.collection('chats').doc(sessionId).collection('messages').orderBy('createdAt','desc').limit(10).get();
      console.log('Found', snaps.size, 'messages');
      snaps.forEach(doc => console.log(doc.id, doc.data()));
    } else {
      console.log('No sessionId returned; searching for recent messages with same userMessage text...');
      // Search recent chat messages for matching text
      const q = await db.collectionGroup('messages').where('text','>=', message.slice(0,20)).limit(20).get();
      console.log('CollectionGroup query returned', q.size);
      q.forEach(doc => console.log(doc.ref.path, doc.data()));
    }

    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(2);
  }
})();
