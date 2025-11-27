const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Social Studies Topics (12 topics as specified)
const SOCIAL_STUDIES_TOPICS = [
  // Strand 1: Environment
  'Our Physical Environment',
  'Human Environment',
  'Resources & Sustainability',

  // Strand 2: Governance, Politics & Stability
  'Rule of Law',
  'Democracy',
  'Local & Central Government',

  // Strand 3: Social & Economic Development
  'Population',
  'Production & Entrepreneurship',
  'Tourism & Development',

  // Strand 4: History of Ghana
  'Ancient Ghana',
  'Colonialism & Independence',
  'Post-Independence Ghana'
];

async function createSocialStudiesTopicCollections() {
  try {
    console.log('📚 Creating Social Studies Topic Collections...\n');

    const indexPath = path.join('assets', 'social_studies_questions_by_topic', 'index.json');
    const indexData = JSON.parse(await fs.readFile(indexPath, 'utf8'));

    let batch = db.batch();
    let batchCount = 0;
    let totalCollectionsCreated = 0;

    for (const topicInfo of indexData.topics) {
      const topicName = topicInfo.name;
      const filename = topicInfo.filename;
      const questionCount = topicInfo.questionCount;

      if (questionCount === 0) {
        console.log(`⏭️  Skipping ${topicName} (no questions)`);
        continue;
      }

      // Read the topic file to get question IDs
      const topicFilePath = path.join('assets', 'social_studies_questions_by_topic', filename);
      const topicData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Extract question IDs
      const questionIds = topicData.questions.map(q => q.id);

      // Create collection document
      const collectionId = `social_studies_topic_${filename.replace('.json', '')}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE Social Studies ${topicName}`,
        description: `Practice ${questionCount} Social Studies questions on ${topicName}`,
        subject: 'socialStudies',
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

      console.log(`✅ Created: BECE Social Studies ${topicName} (${questionCount} questions)`);

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
    console.log('📊 SOCIAL STUDIES CREATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Social Studies Topic Collections Created: ${totalCollectionsCreated}`);
    console.log('='.repeat(70));

    console.log('\n✅ All Social Studies topic collections have been created in Firestore!');
    console.log('📍 Collection: questionCollections');
    console.log('\n🎯 Next Steps:');
    console.log('   1. The collections are now available in the Questions page');
    console.log('   2. Users can filter by Subject: Social Studies to see all topic collections');
    console.log('   3. Each collection shows the topic name and question count');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the creation
createSocialStudiesTopicCollections();