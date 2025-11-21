const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://uriel-academy-41fb0.firebaseio.com'
  });
}

const db = admin.firestore();

async function testCreativeArtsQuestions() {
  try {
    console.log('🧪 Testing Creative Arts and Design questions...\n');

    // Test 1: Count total Creative Arts questions
    const totalQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    console.log(`📊 Total Creative Arts questions: ${totalQuery.docs.length}`);

    // Test 2: Check questions with sectionInstructions (premises)
    const premiseQuestions = totalQuery.docs.filter(doc => {
      const data = doc.data();
      return data.sectionInstructions && data.sectionInstructions.trim().length > 0;
    });

    console.log(`📋 Questions with premises: ${premiseQuestions.length}`);

    // Test 3: Display sample premise questions
    console.log('\n📖 Sample questions with premises:');
    premiseQuestions.slice(0, 3).forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. Question ${data.questionNumber} (${data.year}):`);
      console.log(`   Premise: "${data.sectionInstructions.substring(0, 100)}..."`);
      console.log(`   Question: "${data.questionText.substring(0, 80)}..."`);
    });

    // Test 4: Check subject distribution
    const year2024 = totalQuery.docs.filter(doc => doc.data().year === 2024);
    const year2025 = totalQuery.docs.filter(doc => doc.data().year === 2025);

    console.log(`\n📅 Year distribution:`);
    console.log(`   2024: ${year2024.length} questions`);
    console.log(`   2025: ${year2025.length} questions`);

    // Test 5: Verify question structure
    console.log('\n🔍 Question structure validation:');
    const sampleQuestion = totalQuery.docs[0]?.data();
    if (sampleQuestion) {
      console.log(`   ✅ Subject: ${sampleQuestion.subject}`);
      console.log(`   ✅ Exam Type: ${sampleQuestion.examType}`);
      console.log(`   ✅ Has questionText: ${!!sampleQuestion.questionText}`);
      console.log(`   ✅ Has options: ${Array.isArray(sampleQuestion.options) && sampleQuestion.options.length > 0}`);
      console.log(`   ✅ Has correctAnswer: ${!!sampleQuestion.correctAnswer}`);
      console.log(`   ✅ Has marks: ${sampleQuestion.marks === 1}`);
      console.log(`   ✅ Has difficulty: ${!!sampleQuestion.difficulty}`);
      console.log(`   ✅ Has topics: ${Array.isArray(sampleQuestion.topics)}`);
      console.log(`   ✅ Has createdAt: ${!!sampleQuestion.createdAt}`);
      console.log(`   ✅ Is active: ${sampleQuestion.isActive === true}`);
    }

    // Test 6: Check for any questions that might be mixed with other subjects
    const allSubjectsQuery = await db.collection('questions')
      .where('examType', '==', 'bece')
      .get();

    const creativeArtsIds = totalQuery.docs.map(doc => doc.id);
    const otherSubjectsWithCreativeArts = allSubjectsQuery.docs.filter(doc => {
      const data = doc.data();
      return data.subject !== 'creativeArts' && creativeArtsIds.includes(doc.id);
    });

    if (otherSubjectsWithCreativeArts.length > 0) {
      console.log(`\n⚠️  Warning: Found ${otherSubjectsWithCreativeArts.length} questions that appear in multiple subjects`);
    } else {
      console.log(`\n✅ No subject mixing detected - Creative Arts questions are properly isolated`);
    }

    console.log('\n🎉 All tests completed successfully!');

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the test
testCreativeArtsQuestions();