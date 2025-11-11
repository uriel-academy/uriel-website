// check_proper_ghanaian.js
// Check only the properly formatted Ghanaian Language questions
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Fetching properly formatted Ghanaian Language questions...\n');
    
    // Query for multiple_choice type questions with section field
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .where('type', '==', 'multiple_choice')
      .limit(5)
      .get();
    
    console.log(`Found ${snapshot.size} properly formatted questions\n`);
    console.log('='.repeat(80));
    
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\nQuestion ${index + 1} (ID: ${doc.id}):`);
      console.log('-'.repeat(80));
      console.log(`Subject: ${data.subject}`);
      console.log(`Type: ${data.type}`);
      console.log(`Exam Type: ${data.examType}`);
      console.log(`Year: ${data.year}`);
      console.log(`Section (Language): ${data.section}`);
      console.log(`Topics: ${JSON.stringify(data.topics)}`);
      console.log(`Question: ${data.questionText?.substring(0, 80)}...`);
      console.log(`Options (${data.options?.length}): ${JSON.stringify(data.options)}`);
      console.log(`Correct Answer: ${data.correctAnswer}`);
      console.log(`Is Active: ${data.isActive}`);
      console.log('='.repeat(80));
    });
    
    // Count all properly formatted questions
    const allProper = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .where('type', '==', 'multiple_choice')
      .get();
    
    console.log(`\n✅ Total properly formatted Ghanaian Language questions: ${allProper.size}`);
    
    // Count by section
    const gaCount = allProper.docs.filter(doc => doc.data().section === 'Ga').length;
    const asanteTwiCount = allProper.docs.filter(doc => doc.data().section === 'Asante Twi').length;
    
    console.log(`   - Ga: ${gaCount} questions`);
    console.log(`   - Asante Twi: ${asanteTwiCount} questions`);
    
    // Count malformed questions
    const allMalformed = await db.collection('questions')
      .where('subject', '==', 'ghanaianLanguage')
      .where('type', '==', 'shortAnswer')
      .get();
    
    console.log(`\n⚠️  Malformed shortAnswer questions to delete: ${allMalformed.size}`);
    
    process.exit(0);
  } catch (e) {
    console.error('Error checking questions:', e);
    process.exit(1);
  }
})();
