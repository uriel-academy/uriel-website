const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeUnclassifiedFrenchQuestions() {
  try {
    console.log('🇫🇷 Distributing unclassified French questions to small topics...\n');

    // Topics with fewer questions that will receive unclassified questions
    const smallTopics = [
      { name: 'Verbs & Conjugation', collectionId: 'verbs_conjugation' },
      { name: 'Messages & Emails', collectionId: 'messages_emails' }
    ];

    // Load unclassified questions from the JSON file
    const unclassifiedPath = path.join('assets', 'french_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));
    const unclassifiedQuestions = unclassifiedData.questions || [];

    console.log(`📊 Found ${unclassifiedQuestions.length} unclassified questions to distribute`);

    if (unclassifiedQuestions.length === 0) {
      console.log('✅ No unclassified questions to distribute!');
      return;
    }

    // Calculate distribution (evenly among small topics)
    const questionsPerTopic = Math.floor(unclassifiedQuestions.length / smallTopics.length);
    const remainder = unclassifiedQuestions.length % smallTopics.length;

    console.log(`📊 Distributing ${questionsPerTopic} questions per topic, with ${remainder} extra`);

    let questionIndex = 0;
    const batch = db.batch();

    for (let i = 0; i < smallTopics.length; i++) {
      const topic = smallTopics[i];
      const collectionRef = db.collection('subjects').doc('french').collection('topicCollections').doc(topic.collectionId);
      const doc = await collectionRef.get();

      if (!doc.exists) {
        console.log(`⚠️  Collection ${topic.collectionId} not found, skipping`);
        continue;
      }

      const collectionData = doc.data();
      const existingQuestions = collectionData.questions || [];
      const existingCount = existingQuestions.length;

      // Calculate how many questions this topic should receive
      const questionsForThisTopic = questionsPerTopic + (i < remainder ? 1 : 0);
      const startIndex = questionIndex;
      const endIndex = startIndex + questionsForThisTopic;
      const questionsToAdd = unclassifiedQuestions.slice(startIndex, endIndex).map(q => q.id);

      console.log(`📝 Adding ${questionsToAdd.length} questions to "${topic.name}" (${existingCount} → ${existingCount + questionsToAdd.length})`);

      // Update the collection with additional questions
      const updatedQuestions = [...existingQuestions, ...questionsToAdd];
      const updatedData = {
        ...collectionData,
        questions: updatedQuestions,
        questionCount: updatedQuestions.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.update(collectionRef, updatedData);
      questionIndex = endIndex;
    }

    // Commit the batch
    await batch.commit();
    console.log('💾 Committed distribution updates');

    // Verify the distribution
    console.log('\n🔍 Verifying distribution...');
    let totalDistributed = 0;

    for (const topic of smallTopics) {
      const collectionRef = db.collection('subjects').doc('french').collection('topicCollections').doc(topic.collectionId);
      const doc = await collectionRef.get();

      if (doc.exists) {
        const data = doc.data();
        console.log(`   • ${topic.name}: ${data.questionCount} questions`);
        totalDistributed += data.questionCount;
      }
    }

    console.log(`\n✅ Successfully distributed ${unclassifiedQuestions.length} unclassified questions!`);
    console.log(`📊 Total questions across distributed topics: ${totalDistributed}`);

  } catch (error) {
    console.error('❌ Error distributing unclassified French questions:', error);
    throw error;
  }
}

// Run the function
distributeUnclassifiedFrenchQuestions()
  .then(() => {
    console.log('\n🎉 French unclassified questions distribution completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to distribute French unclassified questions:', error);
    process.exit(1);
  });