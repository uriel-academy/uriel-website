const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeUnclassifiedOffline() {
  try {
    console.log('🔄 Distributing unclassified RME questions using local JSON files...\n');

    // Read the unclassified questions
    const unclassifiedPath = path.join('assets', 'rme_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));
    const unclassifiedQuestionIds = unclassifiedData.questions.map(q => q.id);

    console.log(`📊 Found ${unclassifiedQuestionIds.length} unclassified questions`);

    // Topics with less than 10 questions
    const smallTopics = [
      { name: 'Decision Making', filename: 'decision_making.json', collectionId: 'rme_topic_decision_making' },
      { name: 'National Symbols', filename: 'national_symbols.json', collectionId: 'rme_topic_national_symbols' },
      { name: 'Patriotism & Citizenship', filename: 'patriotism_citizenship.json', collectionId: 'rme_topic_patriotism_citizenship' },
      { name: 'Prayer & Devotion', filename: 'prayer_devotion.json', collectionId: 'rme_topic_prayer_devotion' }
    ];

    // Calculate distribution
    const questionsPerTopic = Math.floor(unclassifiedQuestionIds.length / smallTopics.length);
    const remainder = unclassifiedQuestionIds.length % smallTopics.length;

    console.log(`📊 Distributing ${questionsPerTopic} questions per topic, with ${remainder} extra`);

    let questionIndex = 0;
    const batch = db.batch();

    for (let i = 0; i < smallTopics.length; i++) {
      const topic = smallTopics[i];

      // Read existing topic data
      const topicPath = path.join('assets', 'rme_questions_by_topic', topic.filename);
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
        description: `Practice ${updatedQuestionCount} RME questions on ${topic.name}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.update(collectionRef, updateData);

      console.log(`✅ ${topic.name}: ${existingQuestionIds.length} → ${updatedQuestionCount} questions (+${newQuestionIds.length})`);
    }

    // Create the general questions collection first (in case it was missing)
    const generalCollectionId = 'rme_topic_general_rme_questions';
    const generalCollectionRef = db.collection('questionCollections').doc(generalCollectionId);

    // Check if it exists
    const generalDoc = await generalCollectionRef.get();
    if (!generalDoc.exists) {
      console.log('⚠️  General questions collection not found, creating it first...');

      const generalData = {
        id: generalCollectionId,
        name: 'BECE RME General Questions',
        description: `Practice ${unclassifiedQuestionIds.length} general RME questions covering various topics`,
        subject: 'religiousMoralEducation',
        examType: 'bece',
        type: 'topic',
        topic: 'General RME Questions',
        year: 'All Years',
        questionIds: unclassifiedQuestionIds,
        questionCount: unclassifiedQuestionIds.length,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(generalCollectionRef, generalData);
      console.log('✅ Created general questions collection');
    }

    // Commit all updates
    await batch.commit();
    console.log('\n💾 Committed all updates');

    // Now delete the general questions collection
    await generalCollectionRef.delete();
    console.log('🗑️  Deleted "BECE RME General Questions" collection');

    console.log('\n' + '='.repeat(70));
    console.log('📊 DISTRIBUTION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total unclassified questions distributed: ${unclassifiedQuestionIds.length}`);
    console.log(`Topics updated: ${smallTopics.length}`);
    console.log(`General questions collection: DELETED`);
    console.log('='.repeat(70));

    console.log('\n✅ Unclassified questions successfully distributed!');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

distributeUnclassifiedOffline();