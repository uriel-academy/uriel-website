const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  });
}

const db = admin.firestore();

async function checkMixedSubjects() {
  console.log('🔍 Checking for mixed subjects in questions...\n');

  try {
    const questionsSnapshot = await db.collection('questions').get();

    console.log(`📊 Total questions: ${questionsSnapshot.size}\n`);

    // Check for questions that have RME topics but wrong subjects
    const mixedRME = [];
    const careerTechQuestions = [];
    const creativeArtsQuestions = [];
    const frenchQuestions = [];

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || '';
      const topics = data.topics || [];
      const year = data.year || '';

      // Check for RME questions with wrong topics
      if (subject === 'religiousMoralEducation' || subject === 'rme') {
        const wrongTopics = topics.filter(topic =>
          topic.toLowerCase().includes('french') ||
          topic.toLowerCase().includes('creative') ||
          topic.toLowerCase().includes('career') ||
          topic.toLowerCase().includes('technology') ||
          topic.toLowerCase().includes('art') ||
          topic.toLowerCase().includes('design')
        );
        if (wrongTopics.length > 0) {
          mixedRME.push({
            id: doc.id,
            subject,
            year,
            topics,
            wrongTopics
          });
        }
      }

      // Check for career technology questions
      if (subject === 'career_technology' || subject === 'careerTechnology') {
        careerTechQuestions.push({
          id: doc.id,
          subject,
          year,
          topics
        });
      }

      // Check for creative arts questions
      if (subject === 'creative_art_and_design' || subject === 'creativeArts') {
        creativeArtsQuestions.push({
          id: doc.id,
          subject,
          year,
          topics
        });
      }

      // Check for french questions
      if (subject.toLowerCase().includes('french')) {
        frenchQuestions.push({
          id: doc.id,
          subject,
          year,
          topics
        });
      }
    });

    console.log('🔍 RME Questions with wrong topics:');
    if (mixedRME.length > 0) {
      mixedRME.forEach(q => {
        console.log(`  ID: ${q.id}, Year: ${q.year}, Wrong topics: ${q.wrongTopics.join(', ')}`);
      });
    } else {
      console.log('  None found');
    }

    console.log('\n🏭 Career Technology Questions:');
    if (careerTechQuestions.length > 0) {
      careerTechQuestions.forEach(q => {
        console.log(`  ID: ${q.id}, Year: ${q.year}, Topics: ${q.topics.join(', ')}`);
      });
    } else {
      console.log('  None found');
    }

    console.log('\n🎨 Creative Arts Questions:');
    if (creativeArtsQuestions.length > 0) {
      creativeArtsQuestions.forEach(q => {
        console.log(`  ID: ${q.id}, Year: ${q.year}, Topics: ${q.topics.join(', ')}`);
      });
    } else {
      console.log('  None found');
    }

    console.log('\n🇫🇷 French Questions:');
    if (frenchQuestions.length > 0) {
      frenchQuestions.forEach(q => {
        console.log(`  ID: ${q.id}, Year: ${q.year}, Topics: ${q.topics.join(', ')}`);
      });
    } else {
      console.log('  None found');
    }

    // Summary
    console.log('\n📋 Summary:');
    console.log(`  Mixed RME questions: ${mixedRME.length}`);
    console.log(`  Career Technology questions: ${careerTechQuestions.length}`);
    console.log(`  Creative Arts questions: ${creativeArtsQuestions.length}`);
    console.log(`  French questions: ${frenchQuestions.length}`);

    return {
      mixedRME,
      careerTechQuestions,
      creativeArtsQuestions,
      frenchQuestions
    };

  } catch (error) {
    console.error('❌ Error checking mixed subjects:', error);
  }
}

async function deleteUnwantedQuestions() {
  console.log('\n🗑️  Deleting unwanted questions...\n');

  try {
    const results = await checkMixedSubjects();
    const batch = db.batch();
    let deleteCount = 0;

    // Delete career technology questions
    results.careerTechQuestions.forEach(q => {
      batch.delete(db.collection('questions').doc(q.id));
      deleteCount++;
      console.log(`🗑️  Deleting Career Technology: ${q.id} (${q.year})`);
    });

    // Delete creative arts questions
    results.creativeArtsQuestions.forEach(q => {
      batch.delete(db.collection('questions').doc(q.id));
      deleteCount++;
      console.log(`🗑️  Deleting Creative Arts: ${q.id} (${q.year})`);
    });

    // Delete french questions
    results.frenchQuestions.forEach(q => {
      batch.delete(db.collection('questions').doc(q.id));
      deleteCount++;
      console.log(`🗑️  Deleting French: ${q.id} (${q.year})`);
    });

    // Delete mixed RME questions
    results.mixedRME.forEach(q => {
      batch.delete(db.collection('questions').doc(q.id));
      deleteCount++;
      console.log(`🗑️  Deleting Mixed RME: ${q.id} (${q.year}) - ${q.wrongTopics.join(', ')}`);
    });

    if (deleteCount > 0) {
      await batch.commit();
      console.log(`\n✅ Successfully deleted ${deleteCount} unwanted questions`);
    } else {
      console.log('\nℹ️  No unwanted questions found to delete');
    }

  } catch (error) {
    console.error('❌ Error deleting questions:', error);
  }
}

// Run the check
checkMixedSubjects().then((results) => {
  const totalUnwanted = results.careerTechQuestions.length +
                       results.creativeArtsQuestions.length +
                       results.frenchQuestions.length +
                       results.mixedRME.length;

  if (totalUnwanted > 0) {
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(`\n❓ Found ${totalUnwanted} unwanted questions. Delete them? (yes/no): `, (answer) => {
      if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
        deleteUnwantedQuestions().then(() => {
          console.log('\n🔄 Re-running analysis after deletion...');
          return checkMixedSubjects();
        }).then(() => {
          console.log('\n✅ Cleanup complete!');
          process.exit(0);
        });
      } else {
        console.log('ℹ️  Deletion cancelled.');
        process.exit(0);
      }
      rl.close();
    });
  } else {
    console.log('\n✅ No unwanted questions found. Cleanup not needed.');
  }
}).catch(error => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});