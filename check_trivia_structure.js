const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkTrivia() {
  try {
    console.log('Checking trivia collection...\n');
    
    const snapshot = await db.collection('trivia').limit(5).get();
    
    console.log(`Total trivia documents found: ${snapshot.size}\n`);
    
    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`Doc ID: ${doc.id}`);
      console.log(`Fields: ${Object.keys(data).join(', ')}`);
      
      if (data.category) console.log(`  category: "${data.category}"`);
      if (data.triviaCategory) console.log(`  triviaCategory: "${data.triviaCategory}"`);
      if (data.subject) console.log(`  subject: "${data.subject}"`);
      if (data.examType) console.log(`  examType: "${data.examType}"`);
      if (data.question) console.log(`  question: "${data.question.substring(0, 50)}..."`);
      console.log('---\n');
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkTrivia();
