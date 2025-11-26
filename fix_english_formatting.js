const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function cleanQuestionText(text) {
  if (!text) return text;
  
  // Remove excessive newlines and spaces
  let cleaned = text
    .replace(/\n{3,}/g, '\n\n')  // Replace 3+ newlines with 2
    .replace(/\n\s+\n/g, '\n\n')  // Remove lines with only spaces
    .replace(/[ \t]+\n/g, '\n')   // Remove trailing spaces on lines
    .replace(/\n[ \t]+/g, '\n')   // Remove leading spaces on lines (except paragraphs)
    .trim();
  
  // Fix common English question patterns
  // Remove section headers that got mixed in with questions
  cleaned = cleaned
    .replace(/\n\s*PART\s+[A-Z]\s*[-:]\s*/gi, '\n\n')
    .replace(/\n\s*SECTION\s+[A-Z]\s*[-:]\s*/gi, '\n\n')
    .replace(/\n\s*COMPREHENSION\s*\[?\d+\s*marks?\]?\s*/gi, '')
    .replace(/\n\s*Read the following passage.*$/gi, '');
  
  // Clean up multiple spaces
  cleaned = cleaned.replace(/  +/g, ' ');
  
  // Final trim and ensure proper spacing
  cleaned = cleaned.trim();
  
  return cleaned;
}

async function fixEnglishQuestions() {
  try {
    console.log('Fetching English theory questions...');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .where('type', '==', 'essay')
      .get();
    
    console.log(`Found ${snapshot.size} English theory questions`);
    
    let fixedCount = 0;
    let batch = db.batch();
    let batchCount = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const originalText = data.questionText;
      const cleanedText = cleanQuestionText(originalText);
      
      if (cleanedText !== originalText) {
        batch.update(doc.ref, { questionText: cleanedText });
        batchCount++;
        fixedCount++;
        
        console.log(`\n=== Fixing Question ${data.year} Q${data.questionNumber} ===`);
        console.log('BEFORE:', originalText.substring(0, 200));
        console.log('AFTER:', cleanedText.substring(0, 200));
        
        // Commit batch every 500 operations
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`Committed batch of ${batchCount} updates`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
    
    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${batchCount} updates`);
    }
    
    console.log(`\n✅ Fixed ${fixedCount} English questions`);
    console.log(`✅ ${snapshot.size - fixedCount} questions were already clean`);
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

fixEnglishQuestions();
