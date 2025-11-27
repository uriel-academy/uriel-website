const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// French Topics (12 topics based on curriculum strands)
const FRENCH_TOPICS = [
  // Strand 1: Communication
  'Greetings',
  'Personal Information',
  'Everyday Conversations',

  // Strand 2: Grammar
  'Verbs & Conjugation',
  'Nouns, Gender & Articles',
  'Structure of Sentences',

  // Strand 3: Reading
  'Comprehension',
  'Vocabulary Themes',
  'Short Text Interpretation',

  // Strand 4: Writing
  'Guided Writing',
  'Messages & Emails',
  'Short Paragraphs'
];

async function createFrenchTopicCollections() {
  try {
    console.log('🇫🇷 Creating French Topic Collections...\n');

    const indexPath = path.join('assets', 'french_questions_by_topic', 'index.json');
    const indexData = JSON.parse(await fs.readFile(indexPath, 'utf8'));

    let batch = db.batch();
    let batchCount = 0;
    let totalCollectionsCreated = 0;

    for (const topic of FRENCH_TOPICS) {
      const topicData = indexData.topics.find(t => t.name === topic);

      if (!topicData || topicData.questionCount === 0) {
        console.log(`⏭️  Skipping "${topic}" - No questions`);
        continue;
      }

      console.log(`📝 Creating collection for "${topic}" (${topicData.questionCount} questions)`);

      // Load the actual questions for this topic
      const topicFilePath = path.join('assets', 'french_questions_by_topic', topicData.filename);
      const topicFileData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Create the topic collection document
      const topicKey = topic.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_');
      const collectionId = `french_topic_${topicKey}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE French ${topic}`,
        description: `Practice ${topicData.questionCount} French questions on ${topic}`,
        subject: 'french',
        examType: 'bece',
        type: 'topic',
        topic: topic,
        year: 'All Years',
        isActive: true,
        createdBy: 'system',
        questionCount: topicData.questionCount,
        questionIds: topicFileData.questions.map(q => q.id),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      batch.set(collectionRef, collectionData);
      batchCount++;

      // Commit batch if it reaches 500 operations (Firestore limit)
      if (batchCount >= 450) {
        console.log('💾 Committing batch of collections...');
        try {
          await batch.commit();
          console.log('✅ Batch committed successfully');
        } catch (error) {
          console.error('❌ Error committing batch:', error);
          throw error;
        }
        batch = db.batch();
        batchCount = 0;
      }

      totalCollectionsCreated++;
    }

    // Commit remaining batch
    if (batchCount > 0) {
      console.log('💾 Committing final batch of collections...');
      try {
        await batch.commit();
        console.log('✅ Final batch committed successfully');
      } catch (error) {
        console.error('❌ Error committing final batch:', error);
        throw error;
      }
    }

    console.log(`\n✅ Successfully created ${totalCollectionsCreated} French topic collections!`);
    console.log('📊 Collection Summary:');

    // Display summary
    for (const topic of FRENCH_TOPICS) {
      const topicKey = topic.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_');
      const topicData = indexData.topics[topic];

      if (topicData && topicData.questionCount > 0) {
        console.log(`   • ${topic}: ${topicData.questionCount} questions`);
      }
    }

  } catch (error) {
    console.error('❌ Error creating French topic collections:', error);
    throw error;
  }
}

function getCurriculumStrand(topic) {
  const strandMap = {
    // Strand 1: Communication
    'Greetings': 'Communication',
    'Personal Information': 'Communication',
    'Everyday Conversations': 'Communication',

    // Strand 2: Grammar
    'Verbs & Conjugation': 'Grammar',
    'Nouns, Gender & Articles': 'Grammar',
    'Structure of Sentences': 'Grammar',

    // Strand 3: Reading
    'Comprehension': 'Reading',
    'Vocabulary Themes': 'Reading',
    'Short Text Interpretation': 'Reading',

    // Strand 4: Writing
    'Guided Writing': 'Writing',
    'Messages & Emails': 'Writing',
    'Short Paragraphs': 'Writing'
  };

  return strandMap[topic] || 'General';
}

// Run the function
createFrenchTopicCollections()
  .then(() => {
    console.log('\n🎉 French topic collections creation completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to create French topic collections:', error);
    process.exit(1);
  });