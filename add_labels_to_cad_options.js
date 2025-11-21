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

async function addLabelsToCreativeArtsOptions() {
  try {
    console.log('🔧 Adding A-D labels to Creative Arts options...\n');

    // Get all Creative Arts questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    console.log(`📊 Found ${snapshot.docs.length} questions to update`);

    let updated = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Skip if options already have labels
      if (data.options && data.options.length > 0 && data.options[0].startsWith('A.')) {
        continue;
      }

      // Add A-D labels to options
      const labeledOptions = data.options.map((option, index) => {
        const label = String.fromCharCode(65 + index); // A, B, C, D
        return `${label}. ${option}`;
      });

      // Update correct answer to just the letter
      let correctAnswerLetter = '';
      if (data.correctAnswer && data.options) {
        const correctIndex = data.options.findIndex(option =>
          option.trim().toLowerCase() === data.correctAnswer.trim().toLowerCase()
        );
        if (correctIndex >= 0) {
          correctAnswerLetter = String.fromCharCode(65 + correctIndex);
        }
      }

      // Update the document
      await doc.ref.update({
        options: labeledOptions,
        correctAnswer: correctAnswerLetter
      });

      console.log(`✅ Updated Q${data.questionNumber} (${data.year}): ${correctAnswerLetter}`);
      updated++;
    }

    console.log(`\n🎉 Updated ${updated} questions with A-D labels`);

    // Verification
    console.log('\n🔍 Verifying updates...');
    const verificationQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .limit(3)
      .get();

    verificationQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   Q${data.questionNumber} (${data.year}):`);
      console.log(`     Options: ${JSON.stringify(data.options.slice(0, 2), null, 2)}...`);
      console.log(`     Correct Answer: "${data.correctAnswer}"`);
    });

  } catch (error) {
    console.error('❌ Update failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the update
addLabelsToCreativeArtsOptions();