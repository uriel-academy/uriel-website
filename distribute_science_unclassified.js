const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeScienceUnclassified() {
  try {
    console.log('🔄 Distributing unclassified Science questions to smallest topics...\n');

    // Topics with least questions that will receive unclassified questions
    const smallTopics = [
      { name: 'Electricity & Magnetism', filename: 'electricity_magnetism.json', collectionId: 'science_topic_electricity_magnetism' },
      { name: 'Ecosystems', filename: 'ecosystems.json', collectionId: 'science_topic_ecosystems' },
      { name: 'Environmental Conservation', filename: 'environmental_conservation.json', collectionId: 'science_topic_environmental_conservation' },
      { name: 'Earth Processes', filename: 'earth_processes.json', collectionId: 'science_topic_earth_processes' }
    ];

    // Read the unclassified questions
    const unclassifiedPath = path.join('assets', 'science_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));
    const unclassifiedQuestionIds = unclassifiedData.questions.map(q => q.id);

    console.log(`📊 Found ${unclassifiedQuestionIds.length} unclassified questions`);

    // Calculate distribution (evenly among 4 topics)
    const questionsPerTopic = Math.floor(unclassifiedQuestionIds.length / smallTopics.length);
    const remainder = unclassifiedQuestionIds.length % smallTopics.length;

    console.log(`📊 Distributing ${questionsPerTopic} questions per topic, with ${remainder} extra`);

    let questionIndex = 0;
    const batch = db.batch();

    for (let i = 0; i < smallTopics.length; i++) {
      const topic = smallTopics[i];

      // Read existing topic data
      const topicPath = path.join('assets', 'science_questions_by_topic', topic.filename);
      const topicData = JSON.parse(await fs.readFile(topicPath, 'utf8'));
      const existingQuestionIds = topicData.questions.map(q => q.id);

      // Calculate how many questions this topic gets
      const questionsForThisTopic = questionsPerTopic + (i < remainder ? 1 : 0);
      const newQuestionIds = unclassifiedQuestionIds.slice(questionIndex, questionIndex + questionsForThisTopic);
      questionIndex += questionsForThisTopic;

      // Combine existing and new question IDs
      const updatedQuestionIds = [...existingQuestionIds, ...newQuestionIds];
      const updatedQuestionCount = updatedQuestionIds.length;

      // Update the collection in Firestore
      const collectionRef = db.collection('questionCollections').doc(topic.collectionId);
      const updateData = {
        questionIds: updatedQuestionIds,
        questionCount: updatedQuestionCount,
        description: `Practice ${updatedQuestionCount} Science questions on ${topic.name}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.update(collectionRef, updateData);

      console.log(`✅ ${topic.name}: ${existingQuestionIds.length} → ${updatedQuestionCount} questions (+${newQuestionIds.length})`);
    }

    // Commit all updates
    await batch.commit();
    console.log('\n💾 Committed all updates');

    console.log('\n' + '='.repeat(70));
    console.log('📊 SCIENCE DISTRIBUTION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total unclassified questions distributed: ${unclassifiedQuestionIds.length}`);
    console.log(`Topics updated: ${smallTopics.length}`);
    console.log('='.repeat(70));

    console.log('\n✅ Unclassified Science questions successfully distributed!');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

distributeScienceUnclassified();