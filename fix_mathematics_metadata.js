const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function fixMathematicsQuestions() {
  console.log('🔧 Fixing mathematics questions...\n');
  
  try {
    // Get all mathematics questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .get();
    
    console.log(`Found ${snapshot.size} mathematics questions to update\n`);
    
    let updated = 0;
    let batch = db.batch();
    let batchCount = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Prepare updates
      const updates = {
        examType: 'bece',
        type: 'multipleChoice',
        section: data.section || 'A',
        marks: data.marks || 1,
        difficulty: data.difficulty || 'medium',
        topics: data.topics || ['Mathematics', 'BECE', data.year],
        isActive: data.isActive !== undefined ? data.isActive : true,
        createdBy: data.createdBy || 'system_import',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      batch.update(doc.ref, updates);
      batchCount++;
      updated++;
      
      // Commit batch every 500 documents
      if (batchCount >= 500) {
        await batch.commit();
        console.log(`  ✅ Updated ${updated} questions...`);
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`\n✅ Successfully updated ${updated} mathematics questions!`);
    console.log('\nUpdates applied:');
    console.log('  - examType: "bece"');
    console.log('  - type: "multipleChoice"');
    console.log('  - section: "A"');
    console.log('  - marks: 1');
    console.log('  - difficulty: "medium"');
    console.log('  - topics: ["Mathematics", "BECE", year]');
    console.log('  - isActive: true');
    
  } catch (error) {
    console.error('❌ Error updating questions:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

fixMathematicsQuestions();
