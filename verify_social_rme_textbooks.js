/**
 * Verify Social Studies and RME Textbooks in Firestore
 */

require('dotenv').config();
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function verifyTextbooks() {
  console.log('\n📚 Verifying Social Studies and RME Textbooks in Firestore...\n');
  
  try {
    // Check Social Studies textbooks
    console.log('=== SOCIAL STUDIES TEXTBOOKS ===');
    const socialStudiesSnapshot = await db.collection('textbooks')
      .where('subject', '==', 'Social Studies')
      .get();
    
    console.log(`Found ${socialStudiesSnapshot.size} Social Studies textbooks\n`);
    
    for (const doc of socialStudiesSnapshot.docs) {
      const data = doc.data();
      console.log(`📖 ${doc.id}`);
      console.log(`   Title: ${data.title}`);
      console.log(`   Year: ${data.year}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   Total Chapters: ${data.totalChapters}`);
      console.log(`   Total Sections: ${data.totalSections}`);
      
      // Check chapters
      const chaptersSnapshot = await db.collection('textbooks')
        .doc(doc.id)
        .collection('chapters')
        .get();
      
      console.log(`   Chapters in DB: ${chaptersSnapshot.size}`);
      
      // Check first chapter's sections
      if (chaptersSnapshot.size > 0) {
        const firstChapter = chaptersSnapshot.docs[0];
        const sectionsSnapshot = await db.collection('textbooks')
          .doc(doc.id)
          .collection('chapters')
          .doc(firstChapter.id)
          .collection('sections')
          .get();
        console.log(`   Sections in Chapter 1: ${sectionsSnapshot.size}`);
      }
      console.log('');
    }
    
    // Check RME textbooks
    console.log('\n=== RME TEXTBOOKS ===');
    const rmeSnapshot = await db.collection('textbooks')
      .where('subject', '==', 'Religious and Moral Education')
      .get();
    
    console.log(`Found ${rmeSnapshot.size} RME textbooks\n`);
    
    for (const doc of rmeSnapshot.docs) {
      const data = doc.data();
      console.log(`📖 ${doc.id}`);
      console.log(`   Title: ${data.title}`);
      console.log(`   Year: ${data.year}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   Total Chapters: ${data.totalChapters}`);
      console.log(`   Total Sections: ${data.totalSections}`);
      
      // Check chapters
      const chaptersSnapshot = await db.collection('textbooks')
        .doc(doc.id)
        .collection('chapters')
        .get();
      
      console.log(`   Chapters in DB: ${chaptersSnapshot.size}`);
      
      // Check first chapter's sections
      if (chaptersSnapshot.size > 0) {
        const firstChapter = chaptersSnapshot.docs[0];
        const sectionsSnapshot = await db.collection('textbooks')
          .doc(doc.id)
          .collection('chapters')
          .doc(firstChapter.id)
          .collection('sections')
          .get();
        console.log(`   Sections in Chapter 1: ${sectionsSnapshot.size}`);
      }
      console.log('');
    }
    
    // Summary
    console.log('\n=== SUMMARY ===');
    console.log(`Total Social Studies: ${socialStudiesSnapshot.size}`);
    console.log(`Total RME: ${rmeSnapshot.size}`);
    console.log(`Total Textbooks: ${socialStudiesSnapshot.size + rmeSnapshot.size}`);
    
  } catch (error) {
    console.error('❌ Error verifying textbooks:', error);
  }
  
  process.exit(0);
}

verifyTextbooks();
