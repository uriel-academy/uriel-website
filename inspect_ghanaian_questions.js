// inspect_ghanaian_questions.js
// Check structure of Ghanaian Language questions
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Fetching sample Ghanaian Language questions...\n');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .limit(10)
      .get();
    
    if (snapshot.empty) {
      console.log('No Ghanaian Language questions found.');
      process.exit(0);
    }
    
    console.log(`Total questions fetched: ${snapshot.size}\n`);
    console.log('='.repeat(80));
    
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\nQuestion ${index + 1} (ID: ${doc.id}):`);
      console.log('-'.repeat(80));
      console.log(`Subject: ${data.subject}`);
      console.log(`Type: ${data.type}`);
      console.log(`Exam Type: ${data.examType}`);
      console.log(`Year: ${data.year}`);
      console.log(`Section: ${data.section || 'N/A'}`);
      console.log(`Topics: ${JSON.stringify(data.topics)}`);
      console.log(`Question: ${data.questionText?.substring(0, 100)}...`);
      console.log(`Options: ${JSON.stringify(data.options?.slice(0, 2))}...`);
      console.log(`Correct Answer: ${data.correctAnswer}`);
      console.log(`Is Active: ${data.isActive}`);
      console.log(`Difficulty: ${data.difficulty}`);
      console.log('='.repeat(80));
    });
    
    // Check distinct years
    console.log('\n\nChecking distinct years...');
    const allQuestions = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .get();
    
    const years = new Set();
    const sections = new Set();
    const topics = new Set();
    
    allQuestions.forEach(doc => {
      const data = doc.data();
      if (data.year) years.add(data.year);
      if (data.section) sections.add(data.section);
      if (data.topics && Array.isArray(data.topics)) {
        data.topics.forEach(t => topics.add(t));
      }
    });
    
    console.log(`\nDistinct Years: ${Array.from(years).sort().join(', ')}`);
    console.log(`Distinct Sections: ${Array.from(sections).sort().join(', ')}`);
    console.log(`Distinct Topics: ${Array.from(topics).sort().join(', ')}`);
    console.log(`\nTotal Ghanaian Language questions: ${allQuestions.size}`);
    
    process.exit(0);
  } catch (e) {
    console.error('Error inspecting questions:', e);
    process.exit(1);
  }
})();
