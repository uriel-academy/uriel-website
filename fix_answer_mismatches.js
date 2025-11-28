// Fix verified answer mismatches from validation
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const fixes = [
  {
    year: '2018',
    questionNumber: 20,
    currentAnswer: 'A',
    correctAnswer: 'C',
    subject: 'mathematics',
    reason: 'Official answer key verification'
  },
  {
    year: '2021',
    questionNumber: 25,
    currentAnswer: 'A',
    correctAnswer: 'D',
    subject: 'mathematics',
    reason: 'Official answer key verification'
  }
];

async function fixAnswers() {
  console.log('🔧 FIXING ANSWER MISMATCHES\n');
  console.log('=' .repeat(80) + '\n');
  
  let fixed = 0;
  let failed = 0;
  
  for (const fix of fixes) {
    console.log(`📝 ${fix.subject.toUpperCase()} ${fix.year} Q${fix.questionNumber}`);
    console.log(`   Current: ${fix.currentAnswer} → Correct: ${fix.correctAnswer}`);
    
    try {
      // Find the question
      const snapshot = await db.collection('questions')
        .where('subject', '==', fix.subject)
        .where('year', '==', fix.year)
        .where('questionNumber', '==', fix.questionNumber)
        .where('type', '==', 'multipleChoice')
        .limit(1)
        .get();
      
      if (snapshot.empty) {
        console.log(`   ❌ Question not found\n`);
        failed++;
        continue;
      }
      
      const doc = snapshot.docs[0];
      const data = doc.data();
      
      console.log(`   Question: ${data.questionText.substring(0, 60)}...`);
      console.log(`   Before: ${data.correctAnswer}`);
      
      // Update the answer
      await doc.ref.update({
        correctAnswer: fix.correctAnswer,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`   After: ${fix.correctAnswer}`);
      console.log(`   ✅ Fixed successfully\n`);
      fixed++;
      
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}\n`);
      failed++;
    }
  }
  
  console.log('=' .repeat(80));
  console.log('📊 SUMMARY');
  console.log('=' .repeat(80));
  console.log(`✅ Fixed: ${fixed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`📄 Total: ${fixes.length}\n`);
  
  if (fixed === fixes.length) {
    console.log('✅ SUCCESS: All answer mismatches corrected!');
    console.log('The database now matches official BECE answer keys.\n');
  }
  
  process.exit(failed > 0 ? 1 : 0);
}

fixAnswers().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
