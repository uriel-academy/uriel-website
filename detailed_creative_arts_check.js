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

async function detailedCreativeArtsCheck() {
  try {
    console.log('🔍 Detailed Creative Arts verification...\n');

    // Get all Creative Arts questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    console.log(`📊 Total questions found: ${snapshot.docs.length}`);

    // Analyze by year
    const byYear = {};
    let questionsWithoutAnswers = 0;
    let questionsWithPremises = 0;

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const year = data.year;

      if (!byYear[year]) {
        byYear[year] = [];
      }
      byYear[year].push(data);

      if (!data.correctAnswer || data.correctAnswer.trim() === '') {
        questionsWithoutAnswers++;
      }

      if (data.sectionInstructions && data.sectionInstructions.trim().length > 0) {
        questionsWithPremises++;
      }
    });

    console.log('\n📅 Questions by year:');
    Object.keys(byYear).sort().forEach(year => {
      console.log(`   ${year}: ${byYear[year].length} questions`);
    });

    console.log(`\n❌ Questions without correct answers: ${questionsWithoutAnswers}`);
    console.log(`📋 Questions with premises: ${questionsWithPremises}`);

    // Check specific premise questions
    console.log('\n📖 Questions with premises:');
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.sectionInstructions && data.sectionInstructions.trim().length > 0) {
        console.log(`   Q${data.questionNumber} (${data.year}): "${data.sectionInstructions.substring(0, 60)}..."`);
      }
    });

    // Sample some questions to check structure
    console.log('\n🔍 Sample question structure:');
    if (snapshot.docs.length > 0) {
      const sample = snapshot.docs[0].data();
      console.log(`   ID: ${snapshot.docs[0].id}`);
      console.log(`   Subject: ${sample.subject}`);
      console.log(`   Question: "${sample.questionText.substring(0, 80)}..."`);
      console.log(`   Options: [${sample.options?.join(', ')}]`);
      console.log(`   Correct Answer: "${sample.correctAnswer || 'NOT SET'}"`);
      console.log(`   Section Instructions: "${sample.sectionInstructions ? sample.sectionInstructions.substring(0, 50) + '...' : 'NONE'}"`);
    }

  } catch (error) {
    console.error('❌ Verification failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the detailed check
detailedCreativeArtsCheck();