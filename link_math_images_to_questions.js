const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function linkImages() {
  const mappingFile = 'assets/mathematics_images/image_mapping.json';
  if (!fs.existsSync(mappingFile)) {
    console.error('Image mapping file not found!');
    process.exit(1);
  }
  const imageMapping = JSON.parse(fs.readFileSync(mappingFile, 'utf8'));
  let updated = 0;
  let notFound = 0;
  for (const year of Object.keys(imageMapping)) {
    for (const qNum of Object.keys(imageMapping[year])) {
      const images = imageMapping[year][qNum];
      // Only use the first image for now, as imageBeforeQuestion
      const imageUrl = `https://storage.googleapis.com/uriel-academy-41fb0.firebasestorage.app/mathematics_images/${images[0]}`;
      // Find the question
      const snap = await db.collection('questions')
        .where('subject', '==', 'mathematics')
        .where('year', '==', year)
        .where('questionNumber', '==', parseInt(qNum))
        .limit(1)
        .get();
      if (snap.empty) {
        notFound++;
        console.log(`Not found: ${year} Q${qNum}`);
        continue;
      }
      const doc = snap.docs[0];
      await doc.ref.update({
        imageBeforeQuestion: imageUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      updated++;
      console.log(`Linked: ${year} Q${qNum} -> ${imageUrl}`);
    }
  }
  console.log(`\nDone. Updated: ${updated}, Not found: ${notFound}`);
}

linkImages().catch(err => { console.error(err); process.exit(1); });
