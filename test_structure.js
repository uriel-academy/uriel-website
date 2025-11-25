const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testStructure() {
  console.log('\n=== Testing English Textbook Structure ===\n');
  
  const textbookId = 'english_jhs_1';
  
  // Get chapters
  const chaptersSnap = await db.collection('textbooks').doc(textbookId).collection('chapters').orderBy('chapterNumber').get();
  console.log(`Chapters found: ${chaptersSnap.size}`);
  
  for (let i = 0; i < chaptersSnap.docs.length; i++) {
    const chapterDoc = chaptersSnap.docs[i];
    const chapterData = chapterDoc.data();
    console.log(`\nChapter ${i + 1} (${chapterDoc.id}):`);
    console.log(`  Title: ${chapterData.title}`);
    
    const sectionsSnap = await chapterDoc.ref.collection('sections').orderBy('sectionNumber').get();
    console.log(`  Sections: ${sectionsSnap.size}`);
    
    if (sectionsSnap.size > 0) {
      const firstSection = sectionsSnap.docs[0];
      const sectionData = firstSection.data();
      console.log(`  First section: ${firstSection.id}`);
      console.log(`  Section title: ${sectionData.title}`);
      console.log(`  Has content: ${!!sectionData.content}`);
      console.log(`  Content length: ${sectionData.content?.length || 0} chars`);
    }
  }
  
  process.exit(0);
}

testStructure().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
