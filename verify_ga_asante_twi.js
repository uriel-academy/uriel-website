// verify_ga_asante_twi.js
// Verify Ga and Asante Twi questions are imported correctly
const admin = require('firebase-admin');
const args = require('minimist')(process.argv.slice(2));
const saPath = args.serviceAccount || 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Verifying Ga and Asante Twi questions...\n');
    
    // Check Ga questions
    const gaSnapshot = await db.collection('questions')
      .where('subject', '==', 'ga')
      .limit(3)
      .get();
    
    console.log('='.repeat(80));
    console.log('GA QUESTIONS SAMPLE:');
    console.log('='.repeat(80));
    gaSnapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\nGa Question ${index + 1} (ID: ${doc.id}):`);
      console.log(`Subject: ${data.subject}`);
      console.log(`Type: ${data.type}`);
      console.log(`Year: ${data.year}`);
      console.log(`Question: ${data.questionText?.substring(0, 60)}...`);
      console.log(`Options: ${JSON.stringify(data.options)}`);
      console.log(`Correct Answer: ${data.correctAnswer}`);
    });
    
    // Check Asante Twi questions
    const asanteTwiSnapshot = await db.collection('questions')
      .where('subject', '==', 'asanteTwi')
      .limit(3)
      .get();
    
    console.log('\n' + '='.repeat(80));
    console.log('ASANTE TWI QUESTIONS SAMPLE:');
    console.log('='.repeat(80));
    asanteTwiSnapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\nAsante Twi Question ${index + 1} (ID: ${doc.id}):`);
      console.log(`Subject: ${data.subject}`);
      console.log(`Type: ${data.type}`);
      console.log(`Year: ${data.year}`);
      console.log(`Question: ${data.questionText?.substring(0, 60)}...`);
      console.log(`Options: ${JSON.stringify(data.options)}`);
      console.log(`Correct Answer: ${data.correctAnswer}`);
    });
    
    // Get totals
    const gaTotal = await db.collection('questions').where('subject', '==', 'ga').get();
    const asanteTwiTotal = await db.collection('questions').where('subject', '==', 'asanteTwi').get();
    
    console.log('\n' + '='.repeat(80));
    console.log('TOTALS:');
    console.log(`✅ Ga: ${gaTotal.size} questions`);
    console.log(`✅ Asante Twi: ${asanteTwiTotal.size} questions`);
    console.log(`✅ Combined: ${gaTotal.size + asanteTwiTotal.size} questions`);
    console.log('='.repeat(80));
    
    process.exit(0);
  } catch (e) {
    console.error('Error verifying questions:', e);
    process.exit(1);
  }
})();
