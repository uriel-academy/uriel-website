// Verify mathematics images are correctly linked to questions
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function verifyImages() {
  console.log('🔍 VERIFYING MATHEMATICS IMAGES\n');
  console.log('='.repeat(80) + '\n');
  
  const stats = {
    totalQuestions: 0,
    withImages: 0,
    withoutImages: 0,
    examples: []
  };
  
  // Query all mathematics MCQ questions
  const snapshot = await db.collection('questions')
    .where('subject', '==', 'mathematics')
    .where('type', '==', 'multipleChoice')
    .get();
  
  stats.totalQuestions = snapshot.size;
  
  console.log(`Found ${stats.totalQuestions} mathematics MCQ questions\n`);
  console.log('Checking image links...\n');
  
  snapshot.forEach(doc => {
    const data = doc.data();
    const hasImage = data.imageUrl || data.imageUrls || data.hasImage;
    
    if (hasImage) {
      stats.withImages++;
      
      // Store first 5 examples
      if (stats.examples.length < 5) {
        stats.examples.push({
          year: data.year,
          qNum: data.questionNumber,
          imageUrl: data.imageUrl,
          hasMultiple: data.imageUrls && data.imageUrls.length > 1
        });
      }
    } else {
      stats.withoutImages++;
    }
  });
  
  console.log('=' .repeat(80));
  console.log('📊 SUMMARY');
  console.log('='.repeat(80));
  console.log(`Total MCQ questions: ${stats.totalQuestions}`);
  console.log(`✅ With images: ${stats.withImages} (${((stats.withImages/stats.totalQuestions)*100).toFixed(1)}%)`);
  console.log(`⚠️  Without images: ${stats.withoutImages} (${((stats.withoutImages/stats.totalQuestions)*100).toFixed(1)}%)`);
  
  if (stats.examples.length > 0) {
    console.log('\n📸 Sample questions with images:');
    stats.examples.forEach(ex => {
      console.log(`   ${ex.year} Q${ex.qNum}: ${ex.imageUrl}`);
      if (ex.hasMultiple) console.log(`      (Multiple images attached)`);
    });
  }
  
  console.log('\n');
  process.exit();
}

verifyImages().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
