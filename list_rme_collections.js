const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listRMECollections() {
  try {
    console.log('📋 Listing all RME collections...\n');

    const snapshot = await db.collection('questionCollections')
      .where('subject', '==', 'religiousMoralEducation')
      .where('type', '==', 'topic')
      .get();

    console.log(`Found ${snapshot.size} RME topic collections:\n`);

    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`📁 ${doc.id}`);
      console.log(`   Name: ${data.name}`);
      console.log(`   Questions: ${data.questionCount}`);
      console.log(`   Topic: ${data.topic}`);
      console.log('');
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

listRMECollections();