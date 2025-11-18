const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

db.collection('questions')
  .where('subject', '==', 'mathematics')
  .get()
  .then(snap => {
    let stats = {
      total: 0,
      withImages: 0,
      with4opts: 0,
      with5opts: 0,
      byAnswer: {}
    };
    
    snap.forEach(doc => {
      const q = doc.data();
      stats.total++;
      if (q.imageBeforeQuestion) stats.withImages++;
      if (q.options.length === 4) stats.with4opts++;
      if (q.options.length === 5) stats.with5opts++;
      if (!stats.byAnswer[q.correctAnswer]) stats.byAnswer[q.correctAnswer] = 0;
      stats.byAnswer[q.correctAnswer]++;
    });
    
    console.log('Mathematics Questions Final Stats');
    console.log('='.repeat(50));
    console.log('Total Questions:', stats.total);
    console.log('Questions with Images:', stats.withImages);
    console.log('Questions with 4 options:', stats.with4opts);
    console.log('Questions with 5 options:', stats.with5opts);
    console.log('');
    console.log('Answer Distribution:');
    Object.keys(stats.byAnswer).sort().forEach(ans => {
      const count = stats.byAnswer[ans];
      const pct = Math.round(count / stats.total * 100);
      console.log(`  ${ans}: ${count} (${pct}%)`);
    });
    
    process.exit(0);
  });
