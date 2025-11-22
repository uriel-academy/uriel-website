const admin = require('firebase-admin');
const sa = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(sa)
});

const db = admin.firestore();

async function updateExistingQuestions() {
  // Get all French questions
  const snapshot = await db.collection('french_questions').get();

  console.log(`Found ${snapshot.size} total questions`);

  const batch = db.batch();
  let updateCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const year = data.year;

    // Check if passageId field is missing
    if (!('passageId' in data) && year) {
      const passageId = `french_${year}_passage`.replace(/\s+/g, '_').toLowerCase();

      // Check if the passage exists
      const passageRef = db.collection('french_passages').doc(passageId);
      const passageDoc = await passageRef.get();

      if (passageDoc.exists) {
        batch.update(doc.ref, { passageId });
        updateCount++;
      }
    }
  }

  if (updateCount > 0) {
    await batch.commit();
    console.log(`Updated ${updateCount} questions with passageId`);
  } else {
    console.log('No questions needed updating');
  }
}

updateExistingQuestions().catch(console.error);