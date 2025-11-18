const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

// Keywords that indicate a question likely needs a diagram/image
const imageKeywords = [
  'diagram',
  'graph',
  'chart',
  'figure',
  'shown',
  'above',
  'below',
  'illustrated',
  'triangle',
  'circle',
  'rectangle',
  'shape',
  'line segment',
  'angle',
  'plot',
  'coordinate',
  'table',
  'pictured',
  'image',
  'drawing'
];

async function addImageNotes() {
  console.log('📸 Identifying questions that need diagrams...\n');
  
  try {
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .get();
    
    console.log(`Checking ${snapshot.size} questions...\n`);
    
    let needsImage = 0;
    let batch = db.batch();
    let batchCount = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const questionText = (data.questionText || '').toLowerCase();
      
      // Check if question text contains any image keywords
      const hasImageKeyword = imageKeywords.some(keyword => 
        questionText.includes(keyword.toLowerCase())
      );
      
      if (hasImageKeyword) {
        const currentExplanation = data.explanation || '';
        const imageNote = '\n\n⚠️ Note: This question requires a diagram/figure that is not yet available. The complete question with images will be added soon.';
        
        // Only add note if it doesn't already exist
        if (!currentExplanation.includes('diagram/figure')) {
          batch.update(doc.ref, {
            explanation: currentExplanation + imageNote,
            needsImage: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          needsImage++;
          batchCount++;
          
          // Commit batch every 500 documents
          if (batchCount >= 500) {
            await batch.commit();
            console.log(`  ⚠️  Marked ${needsImage} questions needing images...`);
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
    }
    
    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`\n✅ Marked ${needsImage} mathematics questions as needing diagrams/images`);
    console.log(`\nKeywords used to detect image needs:`);
    console.log(imageKeywords.map(k => `  - ${k}`).join('\n'));
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

addImageNotes();
