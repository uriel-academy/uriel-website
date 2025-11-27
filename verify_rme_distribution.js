const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyRMEDistribution() {
  try {
    console.log('🔍 Verifying RME topic collection distribution...\n');

    const smallTopics = [
      { name: 'Decision Making', collectionId: 'rme_topic_decision_making' },
      { name: 'National Symbols', collectionId: 'rme_topic_national_symbols' },
      { name: 'Patriotism & Citizenship', collectionId: 'rme_topic_patriotism_citizenship' },
      { name: 'Prayer & Devotion', collectionId: 'rme_topic_prayer_devotion' }
    ];

    console.log('Updated small topics:');
    for (const topic of smallTopics) {
      const doc = await db.collection('questionCollections').doc(topic.collectionId).get();
      if (doc.exists) {
        const data = doc.data();
        console.log(`✅ ${topic.name}: ${data.questionCount} questions`);
      } else {
        console.log(`❌ ${topic.name}: Collection not found`);
      }
    }

    // Check if general collection is deleted
    const generalDoc = await db.collection('questionCollections').doc('rme_topic_general_rme_questions').get();
    if (generalDoc.exists) {
      console.log('❌ General questions collection still exists');
    } else {
      console.log('✅ General questions collection successfully deleted');
    }

    // Count total RME collections
    const allRMEDocs = await db.collection('questionCollections')
      .where('subject', '==', 'religiousMoralEducation')
      .where('type', '==', 'topic')
      .get();

    console.log(`\n📊 Total RME topic collections: ${allRMEDocs.size}`);

    // Verify total question count
    let totalQuestions = 0;
    allRMEDocs.forEach(doc => {
      totalQuestions += doc.data().questionCount || 0;
    });

    console.log(`📊 Total questions in all RME collections: ${totalQuestions}`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

verifyRMEDistribution();