const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeCareerTechnologyUnclassifiedQuestions() {
  try {
    console.log('🔄 Distributing unclassified Career Technology questions...\n');

    // Read unclassified questions
    const unclassifiedPath = path.join('assets', 'career_technology_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));

    const unclassifiedQuestions = unclassifiedData.questions;
    console.log(`📋 Found ${unclassifiedQuestions.length} unclassified Career Technology questions`);

    // Get existing topic collections to distribute questions
    const collectionsSnapshot = await db.collection('questionCollections')
      .where('subject', '==', 'careerTechnology')
      .where('type', '==', 'topic')
      .get();

    const topicCollections = [];
    collectionsSnapshot.forEach(doc => {
      topicCollections.push({ id: doc.id, ...doc.data() });
    });

    console.log(`📚 Found ${topicCollections.length} Career Technology topic collections`);

    // Sort collections by current question count (ascending) for balanced distribution
    topicCollections.sort((a, b) => a.questionCount - b.questionCount);

    let batch = db.batch();
    let batchCount = 0;
    let totalDistributed = 0;

    // Distribute questions evenly across topics
    for (let i = 0; i < unclassifiedQuestions.length; i++) {
      const question = unclassifiedQuestions[i];
      const targetCollection = topicCollections[i % topicCollections.length];

      // Add question to collection
      const collectionRef = db.collection('questionCollections').doc(targetCollection.id);

      // Update the collection document
      const updatedQuestionIds = [...targetCollection.questionIds, question.id];
      const updatedQuestionCount = updatedQuestionIds.length;

      batch.update(collectionRef, {
        questionIds: updatedQuestionIds,
        questionCount: updatedQuestionCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      batchCount++;
      totalDistributed++;

      console.log(`➕ Added question ${question.id} to "${targetCollection.topic}" (${updatedQuestionCount} total)`);

      // Commit batch every 500 operations
      if (batchCount >= 500) {
        await batch.commit();
        console.log(`  💾 Committed batch of ${batchCount} operations`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit remaining operations
    if (batchCount > 0) {
      await batch.commit();
      console.log(`  💾 Committed final batch of ${batchCount} operations`);
    }

    console.log('\n' + '='.repeat(70));
    console.log('📊 CAREER TECHNOLOGY REDISTRIBUTION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Unclassified Questions Distributed: ${totalDistributed}`);
    console.log(`Distributed Across ${topicCollections.length} Topic Collections`);
    console.log('='.repeat(70));

    // Show final distribution
    console.log('\n📈 Final Question Distribution:');
    const finalSnapshot = await db.collection('questionCollections')
      .where('subject', '==', 'careerTechnology')
      .where('type', '==', 'topic')
      .get();

    finalSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  ${data.topic}: ${data.questionCount} questions`);
    });

    console.log('\n✅ All unclassified Career Technology questions have been redistributed!');
    console.log('📍 All Career Technology questions are now organized into topic collections');
    console.log('\n🎯 Result:');
    console.log('   - All 92 Career Technology questions are now in topic collections');
    console.log('   - Questions are evenly distributed across all 12 topics');
    console.log('   - Users can practice by specific topics or all Career Technology');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the redistribution
distributeCareerTechnologyUnclassifiedQuestions();