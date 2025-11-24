const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyTextbooks() {
  console.log('\n=== English Textbooks in Firestore ===\n');
  
  const snapshot = await db.collection('textbooks').orderBy('year').get();
  
  if (snapshot.empty) {
    console.log('No textbooks found!');
    return;
  }
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    console.log(`ID: ${doc.id}`);
    console.log(`Title: ${data.title}`);
    console.log(`Year: ${data.year}`);
    console.log(`Subject: ${data.subject}`);
    console.log(`Created: ${data.createdAt?.toDate()}`);
    
    // Count chapters
    const chaptersSnapshot = await db.collection('textbooks').doc(doc.id).collection('chapters').get();
    console.log(`Chapters: ${chaptersSnapshot.size}`);
    
    // Count total sections
    let totalSections = 0;
    for (const chapterDoc of chaptersSnapshot.docs) {
      const sectionsSnapshot = await db.collection('textbooks').doc(doc.id)
        .collection('chapters').doc(chapterDoc.id)
        .collection('sections').get();
      totalSections += sectionsSnapshot.size;
    }
    console.log(`Total Sections: ${totalSections}`);
    console.log('---\n');
  }
  
  console.log('✅ All textbooks verified successfully!');
  process.exit(0);
}

verifyTextbooks().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
