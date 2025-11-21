const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://uriel-academy-41fb0.firebaseio.com'
  });
}

const db = admin.firestore();

async function checkSpecificQuestions() {
  try {
    console.log('🔍 Checking specific Creative Arts questions...\n');

    // Check question 5 specifically
    const q5Query = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('questionNumber', '==', 5)
      .get();

    console.log('Question 5 details:');
    q5Query.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   ID: ${doc.id}`);
      console.log(`   Question: "${data.questionText}"`);
      console.log(`   Options: ${JSON.stringify(data.options, null, 2)}`);
      console.log(`   Options length: ${data.options ? data.options.length : 'NO OPTIONS'}`);
      console.log(`   Correct Answer: "${data.correctAnswer || 'NOT SET'}"`);
      console.log(`   Section Instructions: "${data.sectionInstructions || 'NONE'}"`);
    });

    // Check premise questions (3, 4, 22, 23, 24)
    console.log('\n📖 Premise questions details:');
    const premiseNumbers = [3, 4, 22, 23, 24];

    for (const num of premiseNumbers) {
      const query = await db.collection('questions')
        .where('subject', '==', 'creativeArts')
        .where('questionNumber', '==', num)
        .get();

      query.docs.forEach(doc => {
        const data = doc.data();
        console.log(`\nQ${num} (${data.year}):`);
        console.log(`   Premise: "${data.sectionInstructions}"`);
        console.log(`   Question: "${data.questionText.substring(0, 80)}..."`);
        console.log(`   Options: [${data.options ? data.options.length : 0} options]`);
      });
    }

    // Check questions without answers
    console.log('\n❌ Questions without correct answers:');
    const allQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    allQuery.docs.forEach(doc => {
      const data = doc.data();
      if (!data.correctAnswer || data.correctAnswer.trim() === '') {
        console.log(`   Q${data.questionNumber} (${data.year}): "${data.questionText.substring(0, 50)}..."`);
      }
    });

  } catch (error) {
    console.error('❌ Check failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the check
checkSpecificQuestions();