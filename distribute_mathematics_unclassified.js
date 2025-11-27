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

async function distributeMathematicsUnclassified() {
  try {
    console.log('🔢 Distributing Mathematics Unclassified Questions...\n');

    // Load unclassified questions
    const unclassifiedPath = path.join('assets', 'mathematics_questions_by_topic', '_unclassified.json');
    const unclassifiedData = JSON.parse(await fs.readFile(unclassifiedPath, 'utf8'));

    if (unclassifiedData.questions.length === 0) {
      console.log('✅ No unclassified questions to distribute!');
      return;
    }

    console.log(`📊 Found ${unclassifiedData.questions.length} unclassified questions to distribute`);

    // Get all active topic collections
    const collectionsSnapshot = await db.collection('subjects').doc('mathematics').collection('topicCollections').get();
    const activeCollections = [];

    collectionsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.isActive && data.questionCount > 0) {
        activeCollections.push({
          id: doc.id,
          name: data.name,
          currentCount: data.questionCount,
          questions: data.questions || []
        });
      }
    });

    console.log(`📁 Found ${activeCollections.length} active topic collections`);

    // Sort collections by current question count (ascending) for balanced distribution
    activeCollections.sort((a, b) => a.currentCount - b.currentCount);

    // Distribute questions evenly across collections
    const totalUnclassified = unclassifiedData.questions.length;
    const totalCollections = activeCollections.length;
    const baseQuestionsPerCollection = Math.floor(totalUnclassified / totalCollections);
    const extraQuestions = totalUnclassified % totalCollections;

    console.log(`📈 Distributing ${totalUnclassified} questions across ${totalCollections} collections`);
    console.log(`   • Base questions per collection: ${baseQuestionsPerCollection}`);
    console.log(`   • Extra questions for first ${extraQuestions} collections: 1 each\n`);

    let questionIndex = 0;
    let batch = db.batch();
    let batchCount = 0;

    for (let i = 0; i < activeCollections.length; i++) {
      const collection = activeCollections[i];
      const questionsToAdd = baseQuestionsPerCollection + (i < extraQuestions ? 1 : 0);

      if (questionsToAdd === 0) continue;

      const questionsSlice = unclassifiedData.questions.slice(questionIndex, questionIndex + questionsToAdd);
      questionIndex += questionsToAdd;

      console.log(`📝 Adding ${questionsToAdd} questions to "${collection.name}"`);

      // Update the collection document
      const collectionRef = db.collection('subjects').doc('mathematics').collection('topicCollections').doc(collection.id);

      const updatedQuestions = [...collection.questions, ...questionsSlice.map(q => q.id)];
      const newCount = collection.currentCount + questionsToAdd;

      batch.update(collectionRef, {
        questions: updatedQuestions,
        questionCount: newCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      batchCount++;

      // Commit batch if it reaches 500 operations (Firestore limit)
      if (batchCount >= 450) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
        console.log('💾 Committed batch of updates');
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log('💾 Committed final batch of updates');
    }

    // Verify distribution
    console.log('\n🔍 Verifying distribution...');
    const verificationSnapshot = await db.collection('subjects').doc('mathematics').collection('topicCollections').get();

    let totalQuestions = 0;
    console.log('\n📊 Final Collection Counts:');

    verificationSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.isActive) {
        console.log(`   • ${data.name}: ${data.questionCount} questions`);
        totalQuestions += data.questionCount;
      }
    });

    console.log(`\n✅ Distribution completed! Total questions across all collections: ${totalQuestions}`);

  } catch (error) {
    console.error('❌ Error distributing Mathematics unclassified questions:', error);
    throw error;
  }
}

// Run the function
distributeMathematicsUnclassified()
  .then(() => {
    console.log('\n🎉 Mathematics unclassified questions distribution completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to distribute Mathematics unclassified questions:', error);
    process.exit(1);
  });