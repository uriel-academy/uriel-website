/**
 * Check if questions exist in Firestore sections
 */

require('dotenv').config();
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function checkQuestions() {
  console.log('\n🔍 Checking for questions in Firestore...\n');
  
  try {
    const textbookId = 'social_studies_jhs_1';
    
    // Get first chapter
    const chaptersSnapshot = await db.collection('textbooks')
      .doc(textbookId)
      .collection('chapters')
      .orderBy('chapterNumber')
      .limit(1)
      .get();
    
    if (chaptersSnapshot.empty) {
      console.log('No chapters found');
      return;
    }
    
    const chapter = chaptersSnapshot.docs[0];
    console.log(`📖 Chapter: ${chapter.data().title}\n`);
    
    // Get first section
    const sectionsSnapshot = await db.collection('textbooks')
      .doc(textbookId)
      .collection('chapters')
      .doc(chapter.id)
      .collection('sections')
      .orderBy('sectionNumber')
      .limit(1)
      .get();
    
    if (sectionsSnapshot.empty) {
      console.log('No sections found');
      return;
    }
    
    const section = sectionsSnapshot.docs[0];
    const sectionData = section.data();
    console.log(`📄 Section: ${sectionData.title}`);
    console.log(`   Section ID: ${section.id}`);
    
    // Check if questions exist in section data
    if (sectionData.questions && Array.isArray(sectionData.questions)) {
      console.log(`   ✅ Questions in section data: ${sectionData.questions.length}`);
      console.log('\nFirst question:');
      console.log(JSON.stringify(sectionData.questions[0], null, 2));
    } else {
      console.log(`   ⚠️ No questions array in section data`);
    }
    
    // Check questions subcollection
    const questionsSnapshot = await db.collection('textbooks')
      .doc(textbookId)
      .collection('chapters')
      .doc(chapter.id)
      .collection('sections')
      .doc(section.id)
      .collection('questions')
      .get();
    
    console.log(`\n   Questions subcollection: ${questionsSnapshot.size} documents`);
    
    if (!questionsSnapshot.empty) {
      console.log('\nFirst question from subcollection:');
      const firstQ = questionsSnapshot.docs[0];
      console.log(JSON.stringify({id: firstQ.id, ...firstQ.data()}, null, 2));
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

checkQuestions();
