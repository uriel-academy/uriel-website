const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Mathematics Topics (23 topics based on JHS curriculum strands)
const MATHEMATICS_TOPICS = [
  // Strand 1: NUMBER
  'Whole Numbers',
  'Fractions',
  'Decimals',
  'Percentages',
  'Ratios & Proportions',
  'Indices & Standard Form',
  'Sets',

  // Strand 2: ALGEBRA
  'Algebraic Expressions',
  'Algebraic Operations',
  'Linear Equations',
  'Inequalities',
  'Functions & Relations',
  'Graphs',

  // Strand 3: GEOMETRY & MEASUREMENT
  'Plane Geometry',
  'Circle Geometry',
  'Geometric Constructions',
  'Measurement',
  'Transformations & Symmetry',
  'Pythagoras\' Theorem',

  // Strand 4: DATA & PROBABILITY
  'Data Collection',
  'Data Representation',
  'Measures of Central Tendency',
  'Probability'
];

async function createMathematicsTopicCollections() {
  try {
    console.log('🔢 Creating Mathematics Topic Collections...\n');

    const indexPath = path.join('assets', 'mathematics_questions_by_topic', 'index.json');
    const indexData = JSON.parse(await fs.readFile(indexPath, 'utf8'));

    let batch = db.batch();
    let batchCount = 0;
    let totalCollectionsCreated = 0;

    for (const topic of MATHEMATICS_TOPICS) {
      const topicData = indexData.topics.find(t => t.name === topic);

      if (!topicData || topicData.questionCount === 0) {
        console.log(`⏭️  Skipping "${topic}" - No questions`);
        continue;
      }

      console.log(`📝 Creating collection for "${topic}" (${topicData.questionCount} questions)`);

      // Load the actual questions for this topic
      const topicFilePath = path.join('assets', 'mathematics_questions_by_topic', topicData.filename);
      const topicFileData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Create the topic collection document
      const topicKey = topic.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_');
      const collectionRef = db.collection('subjects').doc('mathematics').collection('topicCollections').doc(topicKey);

      const collectionData = {
        name: topic,
        displayName: topic,
        subject: 'mathematics',
        subjectDisplay: 'Mathematics',
        questionCount: topicData.questionCount,
        questions: topicFileData.questions.map(q => q.id),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        curriculumStrand: getCurriculumStrand(topic),
        difficulty: 'mixed',
        examTypes: ['bece'],
        years: [...new Set(topicFileData.questions.map(q => q.year))].sort()
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

    console.log(`\n✅ Successfully created ${totalCollectionsCreated} Mathematics topic collections!`);
    console.log('📊 Collection Summary:');

    // Display summary
    for (const topic of MATHEMATICS_TOPICS) {
      const topicData = indexData.topics.find(t => t.name === topic);

      if (topicData && topicData.questionCount > 0) {
        console.log(`   • ${topic}: ${topicData.questionCount} questions`);
      }
    }

  } catch (error) {
    console.error('❌ Error creating Mathematics topic collections:', error);
    throw error;
  }
}

function getCurriculumStrand(topic) {
  const strandMap = {
    // Strand 1: NUMBER
    'Whole Numbers': 'Number',
    'Fractions': 'Number',
    'Decimals': 'Number',
    'Percentages': 'Number',
    'Ratios & Proportions': 'Number',
    'Indices & Standard Form': 'Number',
    'Sets': 'Number',

    // Strand 2: ALGEBRA
    'Algebraic Expressions': 'Algebra',
    'Algebraic Operations': 'Algebra',
    'Linear Equations': 'Algebra',
    'Inequalities': 'Algebra',
    'Functions & Relations': 'Algebra',
    'Graphs': 'Algebra',

    // Strand 3: GEOMETRY & MEASUREMENT
    'Plane Geometry': 'Geometry & Measurement',
    'Circle Geometry': 'Geometry & Measurement',
    'Geometric Constructions': 'Geometry & Measurement',
    'Measurement': 'Geometry & Measurement',
    'Transformations & Symmetry': 'Geometry & Measurement',
    'Pythagoras\' Theorem': 'Geometry & Measurement',

    // Strand 4: DATA & PROBABILITY
    'Data Collection': 'Data & Probability',
    'Data Representation': 'Data & Probability',
    'Measures of Central Tendency': 'Data & Probability',
    'Probability': 'Data & Probability'
  };

  return strandMap[topic] || 'General';
}

// Run the function
createMathematicsTopicCollections()
  .then(() => {
    console.log('\n🎉 Mathematics topic collections creation completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to create Mathematics topic collections:', error);
    process.exit(1);
  });