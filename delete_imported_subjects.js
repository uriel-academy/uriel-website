const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteImportedSubjects() {
  try {
    console.log('🗑️ Deleting imported questions for French, Creative Arts, and Career Technology...');

    const subjectsToDelete = ['french', 'creativeArts', 'careerTechnology'];

    for (const subject of subjectsToDelete) {
      console.log(`\n📊 Deleting questions for subject: ${subject}`);

      // Get all questions for this subject
      const query = db.collection('questions').where('subject', '==', subject);
      const snapshot = await query.get();

      console.log(`Found ${snapshot.docs.length} documents to delete`);

      // Delete in batches
      const batchSize = 500;
      let batch = db.batch();
      let count = 0;

      for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        count++;

        if (count % batchSize === 0) {
          await batch.commit();
          console.log(`Deleted ${count} documents so far...`);
          batch = db.batch();
        }
      }

      // Commit remaining
      if (count % batchSize !== 0) {
        await batch.commit();
      }

      console.log(`✅ Deleted ${count} questions for ${subject}`);
    }

    console.log('\n🎉 All specified subjects have been removed from Firestore');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

deleteImportedSubjects();