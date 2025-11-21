const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkCADQuestions() {
  try {
    console.log('🔍 Checking for Creative Arts & Design questions in Firestore...');

    // Query for CAD questions (2024)
    const cad2024Query = db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('year', '==', '2024')
      .limit(5); // Just check first 5

    const cad2024Snapshot = await cad2024Query.get();

    console.log(`📊 Found ${cad2024Snapshot.docs.length} CAD 2024 questions`);

    if (cad2024Snapshot.docs.length > 0) {
      console.log('✅ CAD 2024 questions are live in the app!');
      cad2024Snapshot.docs.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\nQuestion ${index + 1}:`);
        console.log('  ID:', doc.id);
        console.log('  Question:', data.questionText?.substring(0, 100) + '...');
        console.log('  Options:', data.options?.length || 0);
        console.log('  Correct Answer:', data.correctAnswer);
      });
    } else {
      console.log('❌ No CAD 2024 questions found in database');
    }

    // Also check 2025
    const cad2025Query = db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('year', '==', '2025')
      .limit(5);

    const cad2025Snapshot = await cad2025Query.get();

    console.log(`📊 Found ${cad2025Snapshot.docs.length} CAD 2025 questions`);

    if (cad2025Snapshot.docs.length > 0) {
      console.log('✅ CAD 2025 questions are live in the app!');
    } else {
      console.log('❌ No CAD 2025 questions found in database');
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkCADQuestions();