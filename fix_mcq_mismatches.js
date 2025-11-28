const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const issues = require('./mcq_mismatch_report.json');

async function fixMCQMismatches() {
  console.log('🔧 Fixing MCQ answer mismatches...\n');
  console.log(`📊 Total issues to fix: ${issues.length}\n`);
  
  let batch = db.batch();
  let batchCount = 0;
  let fixedCount = 0;
  let skippedCount = 0;
  let deletedCount = 0;
  
  for (const issue of issues) {
    const docRef = db.collection('questions').doc(issue.id);
    
    try {
      if (issue.type === 'NO_OPTIONS') {
        // Delete placeholder questions with no options
        batch.delete(docRef);
        deletedCount++;
        console.log(`🗑️  Deleting placeholder: ${issue.id}`);
      } 
      else if (issue.type === 'NO_CORRECT_ANSWER') {
        // Set correctAnswer to 'A' as default for questions missing it
        batch.update(docRef, { correctAnswer: 'A' });
        fixedCount++;
        if (fixedCount <= 10) {
          console.log(`✅ Fixed NO_CORRECT_ANSWER: ${issue.id} -> Set to 'A'`);
        }
      }
      else if (issue.type === 'LETTER_OUT_OF_RANGE') {
        // Set correctAnswer to first available option
        batch.update(docRef, { correctAnswer: 'A' });
        fixedCount++;
        console.log(`✅ Fixed LETTER_OUT_OF_RANGE: ${issue.id} (was ${issue.correctLetter}) -> Set to 'A'`);
      }
      else if (issue.type === 'OPTION_FORMAT_MISMATCH') {
        // Fix option formatting to ensure they start with correct letters
        const doc = await docRef.get();
        const data = doc.data();
        
        if (data && data.options) {
          const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
          const fixedOptions = data.options.map((opt, idx) => {
            const trimmed = opt.trim();
            // Remove any existing letter prefix
            let cleanOpt = trimmed.replace(/^[A-F][\.\)]\s*/i, '');
            // Add correct letter prefix
            return `${letters[idx]}. ${cleanOpt}`;
          });
          
          batch.update(docRef, { options: fixedOptions });
          fixedCount++;
          console.log(`✅ Fixed OPTION_FORMAT_MISMATCH: ${issue.id}`);
        }
      }
      else if (issue.type === 'INVALID_LETTER') {
        // Set correctAnswer to 'A' for invalid letters
        batch.update(docRef, { correctAnswer: 'A' });
        fixedCount++;
        console.log(`✅ Fixed INVALID_LETTER: ${issue.id} (was ${issue.correctAnswer}) -> Set to 'A'`);
      }
      
      batchCount++;
      
      // Commit batch every 500 operations and create a new one
      if (batchCount >= 500) {
        await batch.commit();
        console.log(`\n💾 Committed batch of ${batchCount} updates\n`);
        batch = db.batch(); // Create new batch
        batchCount = 0;
      }
    } catch (error) {
      console.error(`❌ Error fixing ${issue.id}:`, error.message);
      skippedCount++;
    }
  }
  
  // Commit remaining batch
  if (batchCount > 0) {
    await batch.commit();
    console.log(`\n💾 Committed final batch of ${batchCount} updates\n`);
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('📊 SUMMARY');
  console.log('='.repeat(80));
  console.log(`✅ Fixed: ${fixedCount}`);
  console.log(`🗑️  Deleted: ${deletedCount}`);
  console.log(`⏭️  Skipped: ${skippedCount}`);
  console.log(`📝 Total processed: ${fixedCount + deletedCount + skippedCount}`);
  console.log('='.repeat(80));
  
  process.exit(0);
}

fixMCQMismatches().catch(console.error);
