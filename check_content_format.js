const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkContentFormat() {
  try {
    // First check what textbooks exist
    const textbooksSnap = await db.collection('textbooks')
      .where('subject', '==', 'English')
      .limit(1)
      .get();
    
    if (textbooksSnap.empty) {
      console.log('No English textbooks found');
      return;
    }
    
    const textbookId = textbooksSnap.docs[0].id;
    console.log('Found textbook:', textbookId);
    
    const doc = await db.collection('textbooks')
      .doc(textbookId)
      .collection('chapters')
      .doc('chapter_1')
      .collection('sections')
      .doc('section_1_1')
      .get();
    
    if (!doc.exists) {
      console.log('Document not found');
      return;
    }
    
    const data = doc.data();
    console.log('Content preview (first 500 chars):');
    console.log(data.content.substring(0, 500));
    console.log('\n---');
    console.log('Content type:', typeof data.content);
    console.log('Total length:', data.content.length, 'characters');
    console.log('Has markdown headers:', data.content.includes('#'));
    console.log('Has markdown bold:', data.content.includes('**'));
    console.log('Has markdown images:', data.content.includes('!['));
    console.log('Has HTML images:', data.content.includes('<img'));
    console.log('Has LaTeX math:', data.content.includes('$') || data.content.includes('\\['));
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit();
}

checkContentFormat();
