const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyRMEQuestions() {
  console.log('🔍 Verifying BECE RME Questions in Firestore...\n');
  
  try {
    // Query all RME questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'religiousMoralEducation')
      .where('examType', '==', 'bece')
      .get();
    
    console.log(`📊 Total RME Questions Found: ${snapshot.docs.length}`);
    
    // Group by year
    const questionsByYear = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const year = data.year;
      if (!questionsByYear[year]) {
        questionsByYear[year] = [];
      }
      questionsByYear[year].push(data);
    });
    
    // Display breakdown by year
    console.log('\n📅 Questions by Year:');
    console.log('='.repeat(50));
    
    const years = Object.keys(questionsByYear).sort();
    years.forEach(year => {
      const count = questionsByYear[year].length;
      console.log(`  ${year}: ${count} questions`);
    });
    
    console.log('='.repeat(50));
    
    // Sample a few questions to verify structure
    console.log('\n📝 Sample Questions (First 3):');
    snapshot.docs.slice(0, 3).forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. ${doc.id}`);
      console.log(`   Year: ${data.year}`);
      console.log(`   Question: ${data.questionText.substring(0, 80)}...`);
      console.log(`   Options: ${data.options.length}`);
      console.log(`   Correct: ${data.correctAnswer}`);
      console.log(`   Active: ${data.isActive}`);
    });
    
    // Check metadata
    console.log('\n📊 Checking app_metadata...');
    const metadataDoc = await db.collection('app_metadata').doc('content').get();
    if (metadataDoc.exists) {
      const metadata = metadataDoc.data();
      console.log(`   RME Questions Imported: ${metadata.rmeQuestionsImported}`);
      console.log(`   RME Questions Count: ${metadata.rmeQuestionsCount}`);
      console.log(`   RME Years: ${metadata.rmeYears?.join(', ') || 'Not set'}`);
      console.log(`   Available Years: ${metadata.availableYears?.join(', ') || 'Not set'}`);
    }
    
    console.log('\n✅ Verification Complete!');
    console.log('\n💡 Questions should now appear in:');
    console.log('   - Questions tab → BECE → Religious and Moral Education');
    console.log('   - Past Questions Search → RME filter');
    console.log('   - Quiz Setup → Select RME subject');
    
  } catch (error) {
    console.error('❌ Error verifying questions:', error);
  }
  
  process.exit(0);
}

verifyRMEQuestions();
