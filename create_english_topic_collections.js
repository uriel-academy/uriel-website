const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// English Language Topics (15 topics as specified)
const ENGLISH_TOPICS = [
  // Strand 1: Oral Language
  'Listening Skills',
  'Speaking Skills',
  'Pronunciation',

  // Strand 2: Reading
  'Comprehension',
  'Vocabulary Development',
  'Literary Appreciation',

  // Strand 3: Grammar
  'Parts of Speech',
  'Sentence Structure',
  'Punctuation & Usage',

  // Strand 4: Writing
  'Guided Writing',
  'Composition',
  'Summary Writing',

  // Strand 5: Literature
  'Prose',
  'Poetry',
  'Drama'
];

async function createEnglishTopicCollections() {
  try {
    console.log('📚 Creating English Language Topic Collections...\n');

    const indexPath = path.join('assets', 'english_questions_by_topic', 'index.json');
    const indexData = JSON.parse(await fs.readFile(indexPath, 'utf8'));

    let batch = db.batch();
    let batchCount = 0;
    let totalCollectionsCreated = 0;

    for (const topicInfo of indexData.topics) {
      const topicName = topicInfo.name;
      const filename = topicInfo.filename;
      const questionCount = topicInfo.questionCount;

      // Skip topics with 0 questions as requested
      if (questionCount === 0) {
        console.log(`⏭️  Skipping ${topicName} (no questions)`);
        continue;
      }

      // Read the topic file to get question IDs
      const topicFilePath = path.join('assets', 'english_questions_by_topic', filename);
      const topicData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Extract question IDs
      const questionIds = topicData.questions.map(q => q.id);

      // Create collection document
      const collectionId = `english_topic_${filename.replace('.json', '')}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE English Language ${topicName}`,
        description: `Practice ${questionCount} English Language questions on ${topicName}`,
        subject: 'english',
        examType: 'bece',
        type: 'topic', // New field to identify topic-based collections
        topic: topicName,
        year: 'All Years', // Spans multiple years
        questionIds: questionIds,
        questionCount: questionIds.length,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(collectionRef, collectionData);
      batchCount++;
      totalCollectionsCreated++;

      console.log(`✅ Created: BECE English Language ${topicName} (${questionCount} questions)`);

      // Commit batch every 500 operations (Firestore limit)
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
    console.log('📊 ENGLISH LANGUAGE CREATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total English Language Topic Collections Created: ${totalCollectionsCreated}`);
    console.log('='.repeat(70));

    console.log('\n✅ All English Language topic collections have been created in Firestore!');
    console.log('📍 Collection: questionCollections');
    console.log('\n🎯 Next Steps:');
    console.log('   1. The collections are now available in the Questions page');
    console.log('   2. Users can filter by Subject: English Language to see all topic collections');
    console.log('   3. Each collection shows the topic name and question count');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the creation
createEnglishTopicCollections();