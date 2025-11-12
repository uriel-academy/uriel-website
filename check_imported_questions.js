const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkImportedQuestions() {
  console.log('🔍 Checking imported questions...\n');
  
  // Check Social Studies
  console.log('📚 Social Studies Questions:');
  const ssQuery = await db.collection('questions')
    .where('subject', '==', 'socialStudies')
    .limit(3)
    .get();
  
  console.log(`   Found ${ssQuery.size} questions (showing first 3):`);
  ssQuery.docs.forEach((doc, i) => {
    const data = doc.data();
    console.log(`   ${i + 1}. [${data.year}] Q${data.questionNumber}: ${data.questionText.substring(0, 60)}...`);
    console.log(`      Options: ${data.options.length}`);
    console.log(`      Answer: ${data.correctAnswer || 'N/A'}\n`);
  });
  
  // Check Integrated Science
  console.log('🔬 Integrated Science Questions:');
  const isQuery = await db.collection('questions')
    .where('subject', '==', 'integratedScience')
    .limit(3)
    .get();
  
  console.log(`   Found ${isQuery.size} questions (showing first 3):`);
  isQuery.docs.forEach((doc, i) => {
    const data = doc.data();
    console.log(`   ${i + 1}. [${data.year}] Q${data.questionNumber}: ${data.questionText.substring(0, 60)}...`);
    console.log(`      Options: ${data.options.length}`);
    console.log(`      Answer: ${data.correctAnswer || 'N/A'}\n`);
  });
  
  // Count totals
  console.log('📊 Total Counts:');
  const ssCount = await db.collection('questions')
    .where('subject', '==', 'socialStudies')
    .count()
    .get();
  console.log(`   Social Studies: ${ssCount.data().count} questions`);
  
  const isCount = await db.collection('questions')
    .where('subject', '==', 'integratedScience')
    .count()
    .get();
  console.log(`   Integrated Science: ${isCount.data().count} questions`);
  
  console.log('\n✅ Check complete!');
}

checkImportedQuestions()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
