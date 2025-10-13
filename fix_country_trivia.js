const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixCountryTriviaQuestions() {
  try {
    console.log('🔍 Searching for Country Capitals questions...\n');
    
    // Find all questions with category "Country Capitals"
    const snapshot = await db.collection('trivia')
      .where('category', '==', 'Country Capitals')
      .get();
    
    console.log(`📊 Found ${snapshot.size} Country Capitals questions\n`);
    
    if (snapshot.size === 0) {
      console.log('❌ No questions found with category "Country Capitals"');
      process.exit(1);
    }
    
    console.log('✏️ Updating questions to add required fields...\n');
    
    let updateCount = 0;
    const batch = db.batch();
    
    snapshot.forEach(doc => {
      const data = doc.data();
      
      // Add the required fields for trivia questions
      batch.update(doc.ref, {
        triviaCategory: 'Country',  // This is what QuizTaker looks for
        subject: 'trivia',           // Required by QuestionService filter
        examType: 'trivia',          // Required by QuestionService filter
        // Keep the original category field for reference
        // category: 'Country Capitals' (already exists)
      });
      
      updateCount++;
      
      if (updateCount <= 3) {
        console.log(`Updating doc ${doc.id}:`);
        console.log(`  Question: "${data.question?.substring(0, 50)}..."`);
        console.log(`  Adding: triviaCategory="Country", subject="trivia", examType="trivia"\n`);
      }
    });
    
    // Commit the batch update
    await batch.commit();
    
    console.log(`✅ Successfully updated ${updateCount} questions!`);
    console.log('\n🎯 Country trivia questions are now ready for quizzes!\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixCountryTriviaQuestions();
