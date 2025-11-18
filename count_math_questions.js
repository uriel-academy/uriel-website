const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

db.collection('questions')
  .where('subject', '==', 'mathematics')
  .get()
  .then(snap => {
    const byYear = {};
    snap.forEach(doc => {
      const year = doc.data().year;
      byYear[year] = (byYear[year] || 0) + 1;
    });
    
    console.log('\nMathematics questions by year:');
    console.log('================================');
    Object.keys(byYear).sort().forEach(year => {
      console.log(`${year}: ${byYear[year]} questions`);
    });
    console.log('================================');
    console.log(`TOTAL: ${snap.size} mathematics questions\n`);
    process.exit(0);
  })
  .catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
  });
