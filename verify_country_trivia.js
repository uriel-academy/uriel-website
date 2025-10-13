const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyCountryTrivia() {
  try {
    console.log('🔍 Verifying Country trivia questions can be queried...\n');
    
    // Query exactly as QuizTaker does
    const snapshot = await db.collection('trivia')
      .where('subject', '==', 'trivia')
      .where('examType', '==', 'trivia')
      .where('isActive', '==', true)
      .get();
    
    console.log(`📊 Total trivia questions found: ${snapshot.size}\n`);
    
    // Filter by triviaCategory (this is what QuestionService does in memory)
    let countryCount = 0;
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.triviaCategory === 'Country') {
        countryCount++;
        if (countryCount <= 3) {
          console.log(`✅ Country question ${countryCount}:`);
          console.log(`   "${data.question?.substring(0, 60)}..."`);
          console.log(`   Fields: triviaCategory="${data.triviaCategory}", subject="${data.subject}", examType="${data.examType}"`);
          console.log(`   Options: ${data.options?.length || 0} options`);
          console.log(`   Correct: ${data.correctAnswer}\n`);
        }
      }
    });
    
    console.log(`\n🎯 Total Country trivia questions: ${countryCount}`);
    
    if (countryCount === 194) {
      console.log('✅ SUCCESS! All 194 Country questions are properly configured!\n');
    } else {
      console.log(`⚠️ Expected 194 questions, found ${countryCount}\n`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyCountryTrivia();
