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

async function fixCreativeArtsPremises() {
  try {
    console.log('🔧 Fixing Creative Arts premise instructions...\n');

    // Get all Creative Arts questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    console.log(`📊 Found ${snapshot.docs.length} questions to check`);

    // Define the correct premise instructions
    const premiseFixes = {
      // Question 3 (2024) - T-shirt scenario
      'creativeArts_2024_3': 'Read the scenario below carefully and use it to answer the question below.\n\nAn artist wants to decorate a plain T-shirt for a friend.',
      // Question 4 (2024) - T-shirt scenario
      'creativeArts_2024_4': 'Read the scenario below carefully and use it to answer the question below.\n\nAn artist wants to decorate a plain T-shirt for a friend.',
      // Question 22 (2024) - Agbo Women scenario
      'creativeArts_2024_22': 'Read the scenario below carefully and use it to answer the question below.\n\n"The Agbo Women" political party has 800,000 delegates. The party intends to print clothes for their upcoming rally. Yellow, Blue and Black are the colours for the political party.',
      // Question 23 (2024) - Agbo Women scenario
      'creativeArts_2024_23': 'Read the scenario below carefully and use it to answer the question below.\n\n"The Agbo Women" political party has 800,000 delegates. The party intends to print clothes for their upcoming rally. Yellow, Blue and Black are the colours for the political party.',
      // Question 24 (2024) - Agbo Women scenario
      'creativeArts_2024_24': 'Read the scenario below carefully and use it to answer the question below.\n\n"The Agbo Women" political party has 800,000 delegates. The party intends to print clothes for their upcoming rally. Yellow, Blue and Black are the colours for the political party.'
    };

    let fixed = 0;

    for (const doc of snapshot.docs) {
      const docId = doc.id;
      const data = doc.data();

      if (premiseFixes[docId]) {
        await doc.ref.update({
          sectionInstructions: premiseFixes[docId]
        });
        console.log(`✅ Fixed premise for Q${data.questionNumber} (${data.year})`);
        fixed++;
      }
    }

    console.log(`\n🎉 Fixed ${fixed} premise instructions`);

    // Verification
    console.log('\n🔍 Verifying premise fixes...');
    const verificationQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .where('sectionInstructions', '!=', null)
      .get();

    verificationQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   Q${data.questionNumber} (${data.year}): "${data.sectionInstructions.substring(0, 60)}..."`);
    });

  } catch (error) {
    console.error('❌ Fix failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the fix
fixCreativeArtsPremises();