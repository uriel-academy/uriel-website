const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// RME Topics (15 topics as specified)
const RME_TOPICS = [
  // Strand 1: God, His Creation & Attributes
  'Nature of God',
  'God\'s Creation',
  'Humanity in God\'s Plan',

  // Strand 2: Morality
  'Moral Values',
  'Decision Making',
  'Social Responsibilities',

  // Strand 3: Religion
  'Christianity',
  'Islam',
  'African Traditional Religion',

  // Strand 4: The Family, Society & Nation
  'Family Values',
  'National Symbols',
  'Patriotism & Citizenship',

  // Strand 5: Worship
  'Forms of Worship',
  'Prayer & Devotion',
  'Festivals & Religious Rituals'
];

async function createRMETopicCollections() {
  try {
    console.log('📚 Creating RME Topic Collections...\n');

    const indexPath = path.join('assets', 'rme_questions_by_topic', 'index.json');
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
      const topicFilePath = path.join('assets', 'rme_questions_by_topic', filename);
      const topicData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Extract question IDs
      const questionIds = topicData.questions.map(q => q.id);

      // Create collection document
      const collectionId = `rme_topic_${filename.replace('.json', '')}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE RME ${topicName}`,
        description: `Practice ${questionCount} RME questions on ${topicName}`,
        subject: 'religiousMoralEducation',
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

      console.log(`✅ Created: RME: ${topicName} (${questionCount} questions)`);

      // Commit batch every 500 operations (Firestore limit)
      if (batchCount >= 500) {
        await batch.commit();
        console.log(`  💾 Committed batch of ${batchCount} operations`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Create unclassified questions collection as the 16th topic
    const unclassifiedPath = path.join('assets', 'rme_questions_by_topic', '_unclassified.json');
    try {
      const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));
      const unclassifiedQuestionIds = unclassifiedData.questions.map(q => q.id);
      
      if (unclassifiedQuestionIds.length > 0) {
        const unclassifiedCollectionId = 'rme_topic_general_rme_questions';
        const unclassifiedCollectionRef = db.collection('questionCollections').doc(unclassifiedCollectionId);
        
        const unclassifiedCollectionData = {
          id: unclassifiedCollectionId,
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
        
        batch.set(unclassifiedCollectionRef, unclassifiedCollectionData);
        totalCollectionsCreated++;
        
        console.log(`✅ Created: BECE RME General Questions (${unclassifiedQuestionIds.length} questions)`);
      }
    } catch (error) {
      console.log('⚠️  No unclassified questions file found or error reading it');
    }

    console.log('\n' + '='.repeat(70));
    console.log('📊 RME CREATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total RME Topic Collections Created: ${totalCollectionsCreated}`);
    console.log('='.repeat(70));

    console.log('\n✅ All RME topic collections have been created in Firestore!');
    console.log('📍 Collection: questionCollections');
    console.log('\n🎯 Next Steps:');
    console.log('   1. The collections are now available in the Questions page');
    console.log('   2. Users can filter by Subject: RME to see all topic collections');
    console.log('   3. Each collection shows the topic name and question count');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the creation
createRMETopicCollections();