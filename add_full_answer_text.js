const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function addFullAnswerText() {
  console.log('🔧 Adding full answer text to imported questions...\n');
  
  // Process Social Studies
  console.log('📚 Processing Social Studies...');
  const ssQuery = await db.collection('questions')
    .where('subject', '==', 'socialStudies')
    .get();
  
  let ssUpdated = 0;
  const ssBatch = db.batch();
  
  ssQuery.docs.forEach((doc, index) => {
    const data = doc.data();
    if (data.correctAnswer && data.options) {
      // Find the full answer text from options
      const fullAnswer = data.options.find(opt => opt.startsWith(data.correctAnswer + '.'));
      if (fullAnswer) {
        ssBatch.update(doc.ref, { 
          fullAnswerText: fullAnswer,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        ssUpdated++;
      }
    }
    
    // Commit every 500 documents
    if ((index + 1) % 500 === 0) {
      console.log(`   Processing batch at ${index + 1}...`);
    }
  });
  
  await ssBatch.commit();
  console.log(`   ✅ Updated ${ssUpdated} Social Studies questions\n`);
  
  // Process Integrated Science
  console.log('🔬 Processing Integrated Science...');
  const isQuery = await db.collection('questions')
    .where('subject', '==', 'integratedScience')
    .get();
  
  let isUpdated = 0;
  const isBatch = db.batch();
  
  isQuery.docs.forEach((doc, index) => {
    const data = doc.data();
    if (data.correctAnswer && data.options) {
      // Find the full answer text from options
      const fullAnswer = data.options.find(opt => opt.startsWith(data.correctAnswer + '.'));
      if (fullAnswer) {
        isBatch.update(doc.ref, { 
          fullAnswerText: fullAnswer,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        isUpdated++;
      }
    }
    
    // Commit every 500 documents
    if ((index + 1) % 500 === 0) {
      console.log(`   Processing batch at ${index + 1}...`);
    }
  });
  
  await isBatch.commit();
  console.log(`   ✅ Updated ${isUpdated} Integrated Science questions\n`);
  
  console.log('📊 Summary:');
  console.log(`   Social Studies: ${ssUpdated} questions updated with full answer text`);
  console.log(`   Integrated Science: ${isUpdated} questions updated with full answer text`);
  console.log('\n✅ Update complete!');
}

addFullAnswerText()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Error:', error);
    process.exit(1);
  });
