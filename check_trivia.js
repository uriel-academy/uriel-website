const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://uriel-academy-41fb0-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function checkTriviaQuestions() {
  console.log('🔍 Checking trivia questions in Firestore...');

  try {
    // Get all trivia categories
    const allSnapshot = await db.collection('questions')
      .where('subject', '==', 'trivia')
      .where('examType', '==', 'trivia')
      .get();

    console.log('📊 Total trivia questions:', allSnapshot.docs.length);

    // Group by triviaCategory
    const categories = {};
    allSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const category = data.triviaCategory || 'unknown';
      categories[category] = (categories[category] || 0) + 1;
    });

    console.log('� Trivia categories:');
    Object.keys(categories).forEach(cat => {
      console.log('  -', cat + ':', categories[cat], 'questions');
    });

    // Check for countries and capitals specifically (case variations)
    const variations = ['Countries & Capitals', 'countries and capitals', 'Countries and Capitals'];
    for (const variation of variations) {
      const snapshot = await db.collection('questions')
        .where('subject', '==', 'trivia')
        .where('examType', '==', 'trivia')
        .where('triviaCategory', '==', variation)
        .get();
      console.log('🌍 "' + variation + '" questions:', snapshot.docs.length);
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    admin.app().delete();
  }
}

checkTriviaQuestions();