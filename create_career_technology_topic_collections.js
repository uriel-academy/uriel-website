const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Career Technology Topics (15 topics as specified)
const CAREER_TECHNOLOGY_TOPICS = [
  // Strand 1: Personal & Career Development
  'Personal Competencies',
  'Career Choices',
  'Work Ethics',

  // Strand 2: Sewing & Clothing
  'Tools & Equipment',
  'Basic Stitches',
  'Garment Construction',

  // Strand 3: Food & Nutrition
  'Ingredients & Tools',
  'Meal Planning',
  'Food Preparation',

  // Strand 4: Home Management
  'Cleaning & Maintenance',
  'Safety at Home',
  'Household Resources',

  // Strand 5: Materials Technology
  'Simple Projects',
  'Basic Repairs',
  'Craft Production'
];

async function createCareerTechnologyTopicCollections() {
  try {
    console.log('🔧 Creating Career Technology Topic Collections...\n');

    const indexPath = path.join('assets', 'career_technology_questions_by_topic', 'index.json');
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
      const topicFilePath = path.join('assets', 'career_technology_questions_by_topic', filename);
      const topicData = JSON.parse(await fs.readFile(topicFilePath, 'utf8'));

      // Extract question IDs
      const questionIds = topicData.questions.map(q => q.id);

      // Create collection document
      const collectionId = `career_technology_topic_${filename.replace('.json', '')}`;
      const collectionRef = db.collection('questionCollections').doc(collectionId);

      const collectionData = {
        id: collectionId,
        name: `BECE Career Technology ${topicName}`,
        description: `Practice ${questionCount} Career Technology questions on ${topicName}`,
        subject: 'careerTechnology',
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

      console.log(`✅ Created: BECE Career Technology ${topicName} (${questionCount} questions)`);

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
    console.log('📊 CAREER TECHNOLOGY CREATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Career Technology Topic Collections Created: ${totalCollectionsCreated}`);
    console.log('='.repeat(70));

    console.log('\n✅ All Career Technology topic collections have been created in Firestore!');
    console.log('📍 Collection: questionCollections');
    console.log('\n🎯 Next Steps:');
    console.log('   1. The collections are now available in the Questions page');
    console.log('   2. Users can filter by Subject: Career Technology to see all topic collections');
    console.log('   3. Each collection shows the topic name and question count');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the creation
createCareerTechnologyTopicCollections();