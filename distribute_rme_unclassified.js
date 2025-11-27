const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeUnclassifiedQuestions() {
  try {
    console.log('🔄 Distributing unclassified RME questions to small topics...\n');

    // Topics with less than 10 questions that will receive unclassified questions
    const smallTopics = [
      { name: 'Decision Making', collectionId: 'rme_topic_decision_making' },
      { name: 'National Symbols', collectionId: 'rme_topic_national_symbols' },
      { name: 'Patriotism & Citizenship', collectionId: 'rme_topic_patriotism_citizenship' },
      { name: 'Prayer & Devotion', collectionId: 'rme_topic_prayer_devotion' }
    ];

    // Get the unclassified questions collection
    const generalCollectionRef = db.collection('questionCollections').doc('rme_topic_general_rme_questions');
    const generalDoc = await generalCollectionRef.get();

    if (!generalDoc.exists) {
      console.log('❌ General questions collection not found');
      return;
    }

    const generalData = generalDoc.data();
    const unclassifiedQuestionIds = generalData.questionIds || [];
    console.log(`📊 Found ${unclassifiedQuestionIds.length} unclassified questions to distribute`);

    // Calculate distribution (evenly among 4 topics)
    const questionsPerTopic = Math.floor(unclassifiedQuestionIds.length / smallTopics.length);
    const remainder = unclassifiedQuestionIds.length % smallTopics.length;

    console.log(`📊 Distributing ${questionsPerTopic} questions per topic, with ${remainder} extra`);

    let questionIndex = 0;
    const batch = db.batch();

    for (let i = 0; i < smallTopics.length; i++) {
      const topic = smallTopics[i];
      const collectionRef = db.collection('questionCollections').doc(topic.collectionId);
      const doc = await collectionRef.get();

      if (!doc.exists) {
        console.log(`⚠️  Collection ${topic.collectionId} not found, skipping`);
        continue;
      }

      const existingData = doc.data();
      const existingQuestionIds = existingData.questionIds || [];

      // Calculate how many questions this topic gets
      const questionsForThisTopic = questionsPerTopic + (i < remainder ? 1 : 0);
      const newQuestionIds = unclassifiedQuestionIds.slice(questionIndex, questionIndex + questionsForThisTopic);
      questionIndex += questionsForThisTopic;

      // Combine existing and new question IDs
      const updatedQuestionIds = [...existingQuestionIds, ...newQuestionIds];
      const updatedQuestionCount = updatedQuestionIds.length;

      // Update the collection
      const updatedData = {
        ...existingData,
        questionIds: updatedQuestionIds,
        questionCount: updatedQuestionCount,
        description: `Practice ${updatedQuestionCount} RME questions on ${topic.name}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.update(collectionRef, updatedData);

      console.log(`✅ ${topic.name}: ${existingQuestionIds.length} → ${updatedQuestionCount} questions (+${newQuestionIds.length})`);
    }

    // Commit all updates
    await batch.commit();
    console.log('\n💾 Committed all topic updates');

    // Delete the general questions collection
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
    console.log('🎯 All RME topics now have substantial question counts for effective practice');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

distributeUnclassifiedQuestions();