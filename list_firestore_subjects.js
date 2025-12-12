/**
 * Script to list all subjects in textbook_sections_markdown collection
 */

const admin = require('firebase-admin');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'uriel-academy-41fb0'
});

const firestore = admin.firestore();

async function listSubjects() {
  try {
    const snapshot = await firestore
      .collection('textbook_sections_markdown')
      .limit(50)
      .get();

    console.log(`\n📚 Found ${snapshot.size} documents\n`);

    const subjects = new Set();
    const textbookIds = new Set();

    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.subject) subjects.add(data.subject);
      if (data.textbookId) textbookIds.add(data.textbookId);
      
      console.log(`${doc.id}:`);
      console.log(`  Subject: ${data.subject}`);
      console.log(`  TextbookId: ${data.textbookId}`);
      console.log(`  Title: ${data.title}`);
      console.log();
    });

    console.log('\n📊 Summary:');
    console.log(`Unique subjects: ${Array.from(subjects).join(', ')}`);
    console.log(`Unique textbookIds: ${Array.from(textbookIds).join(', ')}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

listSubjects();
