const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Ga Topics (12 topics based on curriculum strands)
const GA_TOPICS = [
  // Strand 1: Communication & Oral Skills
  'Greetings & Introductions',
  'Family & Relationships',
  'Daily Activities',

  // Strand 2: Grammar & Language Structure
  'Nouns & Pronouns',
  'Verbs & Tenses',
  'Sentence Structure',

  // Strand 3: Vocabulary & Thematic Content
  'Food & Drinks',
  'Animals & Nature',
  'Numbers & Time',

  // Strand 4: Reading & Comprehension
  'Reading Comprehension',

  // Strand 5: Writing & Composition
  'Writing Skills'
];

async function createGaTopicCollections() {
  try {
    console.log('🇬🇭 Creating Ga Topic Collections...\n');

    const indexPath = path.join('assets', 'ga_questions_by_topic', 'index.json');
    const indexData = JSON.parse(await fs.readFile(indexPath, 'utf8'));

    let batch = db.batch();
    let batchCount = 0;
    let totalCollectionsCreated = 0;

    for (const topic of GA_TOPICS) {
      const topicData = indexData.topics.find(t => t.name === topic);

      if (!topicData || topicData.questionCount === 0) {
        console.log(`⏭️  Skipping "${topic}" - No questions`);
        continue;
      }

      console.log(`📝 Creating collection for "${topic}" (${topicData.questionCount} questions)`);

      // Load the actual questions for this topic
      const topicFilePath = path.join('assets', 'ga_questions_by_topic', topicData.filename);
      const topicFileData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Create the topic collection document
      const topicKey = topic.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_');
      const collectionId = `ga_topic_${topicKey}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE GA ${topic}`,
        description: `Practice ${topicData.questionCount} GA questions on ${topic}`,
        subject: 'ga',
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
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
        console.log('💾 Committed batch of collections');
      }

      totalCollectionsCreated++;
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log('💾 Committed final batch of collections');
    }

    console.log(`\n✅ Successfully created ${totalCollectionsCreated} Ga topic collections!`);
    console.log('📊 Collection Summary:');

    // Display summary
    for (const topic of GA_TOPICS) {
      const topicData = indexData.topics.find(t => t.name === topic);

      if (topicData && topicData.questionCount > 0) {
        console.log(`   • ${topic}: ${topicData.questionCount} questions`);
      }
    }

  } catch (error) {
    console.error('❌ Error creating Ga topic collections:', error);
    throw error;
  }
}

function getCurriculumStrand(topic) {
  const strandMap = {
    // Strand 1: Communication & Oral Skills
    'Greetings & Introductions': 'Communication & Oral Skills',
    'Family & Relationships': 'Communication & Oral Skills',
    'Daily Activities': 'Communication & Oral Skills',

    // Strand 2: Grammar & Language Structure
    'Nouns & Pronouns': 'Grammar & Language Structure',
    'Verbs & Tenses': 'Grammar & Language Structure',
    'Sentence Structure': 'Grammar & Language Structure',

    // Strand 3: Vocabulary & Thematic Content
    'Food & Drinks': 'Vocabulary & Thematic Content',
    'Animals & Nature': 'Vocabulary & Thematic Content',
    'Numbers & Time': 'Vocabulary & Thematic Content',

    // Strand 4: Reading & Comprehension
    'Reading Comprehension': 'Reading & Comprehension',

    // Strand 5: Writing & Composition
    'Writing Skills': 'Writing & Composition'
  };

  return strandMap[topic] || 'General';
}

// Run the function
createGaTopicCollections()
  .then(() => {
    console.log('\n🎉 Ga topic collections creation completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to create Ga topic collections:', error);
    process.exit(1);
  });