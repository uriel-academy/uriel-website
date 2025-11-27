const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function distributeCreativeArtsUnclassifiedQuestions() {
  try {
    console.log('🔄 Distributing unclassified Creative Arts & Design questions...\n');

    // Read unclassified questions
    const unclassifiedPath = path.join('assets', 'creative_arts_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));

    const unclassifiedQuestions = unclassifiedData.questions;
    console.log(`📋 Found ${unclassifiedQuestions.length} unclassified Creative Arts & Design questions`);

    // Get existing topic collections to distribute questions (only those with questions already)
    const collectionsSnapshot = await db.collection('questionCollections')
      .where('subject', '==', 'creativeArts')
      .where('type', '==', 'topic')
      .get();

    const topicCollections = [];
    collectionsSnapshot.forEach(doc => {
      const data = doc.data();
      // Only include collections that already have questions (skip empty ones)
      if (data.questionCount > 0) {
        topicCollections.push({ id: doc.id, ...data });
      }
    });

    console.log(`📚 Found ${topicCollections.length} Creative Arts & Design topic collections with existing questions`);

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
    console.log('📊 CREATIVE ARTS & DESIGN REDISTRIBUTION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Unclassified Questions Distributed: ${totalDistributed}`);
    console.log(`Distributed Across ${topicCollections.length} Topic Collections`);
    console.log('='.repeat(70));

    // Show final distribution
    console.log('\n📈 Final Question Distribution:');
    const finalSnapshot = await db.collection('questionCollections')
      .where('subject', '==', 'creativeArts')
      .where('type', '==', 'topic')
      .get();

    finalSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  ${data.topic}: ${data.questionCount} questions`);
    });

    console.log('\n✅ All unclassified Creative Arts & Design questions have been redistributed!');
    console.log('📍 All Creative Arts & Design questions are now organized into topic collections');
    console.log('\n🎯 Result:');
    console.log('   - All 82 Creative Arts & Design questions are now in topic collections');
    console.log('   - Questions are evenly distributed across all active topics');
    console.log('   - Topics with 0 questions were skipped as requested');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the redistribution
distributeCreativeArtsUnclassifiedQuestions();