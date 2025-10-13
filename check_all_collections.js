const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAllCollections() {
  try {
    console.log('🔍 CHECKING BOTH COLLECTIONS FOR TRIVIA DATA\n');
    console.log('=' .repeat(60));
    
    // Check 'questions' collection for trivia
    console.log('\n1️⃣ Checking "questions" collection for trivia...\n');
    const questionsTrivia = await db.collection('questions')
      .where('examType', '==', 'trivia')
      .get();
    console.log(`   Trivia questions in "questions" collection: ${questionsTrivia.size}`);
    
    if (questionsTrivia.size > 0) {
      console.log('\n   ⚠️  WARNING: Found trivia questions in "questions" collection!');
      console.log('   These will now fail after the fix.');
      questionsTrivia.forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.triviaCategory || data.category}: "${data.question?.substring(0, 40)}..."`);
      });
    } else {
      console.log('   ✅ Good: No trivia questions in "questions" collection');
    }
    
    // Check 'trivia' collection
    console.log('\n2️⃣ Checking "trivia" collection...\n');
    const triviaAll = await db.collection('trivia').get();
    console.log(`   Total documents in "trivia" collection: ${triviaAll.size}`);
    
    // Count by triviaCategory
    const categories = {};
    triviaAll.forEach(doc => {
      const data = doc.data();
      const cat = data.triviaCategory || data.category || 'Unknown';
      categories[cat] = (categories[cat] || 0) + 1;
    });
    
    console.log('\n   Breakdown by category:');
    Object.entries(categories).sort((a, b) => b[1] - a[1]).forEach(([cat, count]) => {
      console.log(`     - ${cat}: ${count} questions`);
    });
    
    // Check for questions without proper trivia fields
    console.log('\n3️⃣ Checking for improperly formatted trivia questions...\n');
    const noSubject = await db.collection('trivia')
      .where('subject', '==', null)
      .get();
    console.log(`   Questions without "subject" field: ${noSubject.size}`);
    
    const notTrivia = [];
    triviaAll.forEach(doc => {
      const data = doc.data();
      if (data.subject !== 'trivia' || data.examType !== 'trivia') {
        notTrivia.push({ id: doc.id, subject: data.subject, examType: data.examType });
      }
    });
    
    if (notTrivia.length > 0) {
      console.log(`\n   ⚠️  WARNING: ${notTrivia.length} questions in "trivia" collection don't have subject="trivia" or examType="trivia"`);
      notTrivia.slice(0, 5).forEach(q => {
        console.log(`     - Doc ${q.id}: subject="${q.subject}", examType="${q.examType}"`);
      });
    } else {
      console.log('   ✅ All questions in "trivia" collection have correct fields');
    }
    
    console.log('\n' + '=' .repeat(60));
    console.log('\n✅ CHECK COMPLETE\n');
    
    if (questionsTrivia.size === 0 && notTrivia.length === 0) {
      console.log('🎯 RESULT: Data structure is correct!');
      console.log('   - No trivia in "questions" collection (good)');
      console.log('   - All "trivia" collection questions have correct fields');
      console.log('   - Country trivia should work after deployment');
    } else {
      console.log('⚠️  RESULT: Potential issues found!');
      if (questionsTrivia.size > 0) {
        console.log('   - Trivia questions found in "questions" collection');
        console.log('   - These might break after the fix');
      }
      if (notTrivia.length > 0) {
        console.log('   - Some questions in "trivia" collection have wrong fields');
        console.log('   - These need to be updated');
      }
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkAllCollections();
