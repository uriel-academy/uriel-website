const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeUnclassifiedAsanteTwiQuestions() {
  try {
    console.log('🇹🇼 Distributing unclassified Asante Twi questions to small topics...\n');

    // Topics with fewer questions that will receive unclassified questions
    const smallTopics = [
      { name: 'Food & Drinks', collectionId: 'food_drinks' },
      { name: 'Daily Activities', collectionId: 'daily_activities' }
    ];

    // Load unclassified questions from the JSON file
    const unclassifiedPath = path.join('assets', 'asante_twi_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));
    const unclassifiedQuestions = unclassifiedData.questions || [];

    console.log(`📊 Found ${unclassifiedQuestions.length} unclassified questions to distribute`);

    if (unclassifiedQuestions.length === 0) {
      console.log('✅ No unclassified questions to distribute!');
      return;
    }

    // Since there are only 2 questions, distribute 1 to each small topic
    console.log(`📊 Distributing 1 question to each of the 2 small topics`);

    let questionIndex = 0;
    const batch = db.batch();

    for (const topic of smallTopics) {
      const collectionId = `asante_twi_topic_${topic.collectionId}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);
      const doc = await collectionRef.get();

      if (!doc.exists) {
        console.log(`⚠️  Collection ${topic.collectionId} not found, skipping`);
        continue;
      }

      const collectionData = doc.data();
      const existingQuestions = collectionData.questionIds || [];
      const existingCount = existingQuestions.length;

      // Take 1 question for this topic
      const questionsToAdd = unclassifiedQuestions.slice(questionIndex, questionIndex + 1).map(q => q.id);

      console.log(`📝 Adding ${questionsToAdd.length} questions to "${topic.name}" (${existingCount} → ${existingCount + questionsToAdd.length})`);

      // Update the collection with additional questions
      const updatedQuestions = [...existingQuestions, ...questionsToAdd];
      const updatedData = {
        ...collectionData,
        questionIds: updatedQuestions,
        questionCount: updatedQuestions.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.update(collectionRef, updatedData);
      questionIndex += 1;
    }

    // Commit the batch
    await batch.commit();
    console.log('💾 Committed distribution updates');

    // Verify the distribution
    console.log('\n🔍 Verifying distribution...');
    let totalDistributed = 0;

    for (const topic of smallTopics) {
      const collectionRef = db.collection('subjects').doc('asanteTwi').collection('topicCollections').doc(topic.collectionId);
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
    console.error('❌ Error distributing unclassified Asante Twi questions:', error);
    throw error;
  }
}

// Run the function
distributeUnclassifiedAsanteTwiQuestions()
  .then(() => {
    console.log('\n🎉 Asante Twi unclassified questions distribution completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to distribute Asante Twi unclassified questions:', error);
    process.exit(1);
  });