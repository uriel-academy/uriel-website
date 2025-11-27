const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyScienceDistribution() {
  try {
    console.log('🔍 Verifying Science topic collection distribution...\n');

    const snapshot = await db.collection('questionCollections')
      .where('subject', '==', 'integratedScience')
      .where('type', '==', 'topic')
      .get();

    console.log(`Found ${snapshot.size} Science topic collections:\n`);

    let totalQuestions = 0;
    const topicCounts = [];

    snapshot.forEach(doc => {
      const data = doc.data();
      const count = data.questionCount || 0;
      totalQuestions += count;
      topicCounts.push({ name: data.topic, count: count });
      console.log(`✅ ${data.topic}: ${count} questions`);
    });

    console.log(`\n📊 Total questions in all Science collections: ${totalQuestions}`);

    // Sort by count ascending to show smallest topics
    topicCounts.sort((a, b) => a.count - b.count);
    console.log('\n📊 Topics sorted by question count (ascending):');
    topicCounts.forEach(topic => {
      console.log(`  ${topic.name}: ${topic.count}`);
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

verifyScienceDistribution();