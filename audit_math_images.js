const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function auditMathImages() {
  console.log('Auditing mathematics images...\n');

  // Load image mapping
  const mappingPath = './assets/mathematics_images/image_mapping.json';
  if (!fs.existsSync(mappingPath)) {
    console.error('Image mapping file not found!');
    process.exit(1);
  }
  const imageMapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));

  // Get all mathematics questions from Firestore
  const questionsSnap = await db.collection('questions')
    .where('subject', '==', 'mathematics')
    .get();

  console.log(`Found ${questionsSnap.size} mathematics questions in Firestore\n`);

  let totalWithImages = 0;
  let totalWithBefore = 0;
  let totalWithAfter = 0;
  let totalMalformed = 0;
  let totalMissing = 0;

  const updates = [];

  for (const doc of questionsSnap.docs) {
    const data = doc.data();
    const year = data.year;
    const questionNumber = data.questionNumber;

    // Check if this question should have images according to mapping
    const yearMapping = imageMapping[year];
    const shouldHaveImages = yearMapping && yearMapping[questionNumber];

    if (!shouldHaveImages) continue;

    totalWithImages++;

    const imageBefore = data.imageBeforeQuestion;
    const imageAfter = data.imageAfterQuestion;

    let hasBefore = false;
    let hasAfter = false;
    let malformedBefore = false;
    let malformedAfter = false;

    if (imageBefore) {
      totalWithBefore++;
      hasBefore = true;
      // Check if URL is malformed
      if (typeof imageBefore === 'string') {
        const cleanUrl = imageBefore.replace(/\s+/g, '');
        if (cleanUrl !== imageBefore || !cleanUrl.startsWith('http')) {
          malformedBefore = true;
          totalMalformed++;
          updates.push({
            ref: doc.ref,
            field: 'imageBeforeQuestion',
            value: cleanUrl.startsWith('http') ? cleanUrl : 'https://' + cleanUrl.replace(/^https?:\/\//, '')
          });
        }
      }
    }

    if (imageAfter) {
      totalWithAfter++;
      hasAfter = true;
      // Check if URL is malformed
      if (typeof imageAfter === 'string') {
        const cleanUrl = imageAfter.replace(/\s+/g, '');
        if (cleanUrl !== imageAfter || !cleanUrl.startsWith('http')) {
          malformedAfter = true;
          totalMalformed++;
          updates.push({
            ref: doc.ref,
            field: 'imageAfterQuestion',
            value: cleanUrl.startsWith('http') ? cleanUrl : 'https://' + cleanUrl.replace(/^https?:\/\//, '')
          });
        }
      }
    }

    if (!hasBefore && !hasAfter) {
      totalMissing++;
      console.log(`MISSING: ${year} Q${questionNumber} - should have images but none linked`);
      // Link the first image as imageBeforeQuestion
      const imageFile = yearMapping[questionNumber][0];
      const url = `https://storage.googleapis.com/uriel-academy-41fb0.firebasestorage.app/mathematics_images/${imageFile}`;
      updates.push({
        ref: doc.ref,
        field: 'imageBeforeQuestion',
        value: url
      });
    }

    if (malformedBefore || malformedAfter) {
      console.log(`MALFORMED: ${year} Q${questionNumber} - has malformed URLs`);
    }
  }

  console.log('\n=== AUDIT SUMMARY ===');
  console.log(`Questions that should have images: ${totalWithImages}`);
  console.log(`Questions with imageBeforeQuestion: ${totalWithBefore}`);
  console.log(`Questions with imageAfterQuestion: ${totalWithAfter}`);
  console.log(`Questions with malformed URLs: ${totalMalformed}`);
  console.log(`Questions missing image links: ${totalMissing}`);
  console.log(`Total updates needed: ${updates.length}`);

  if (updates.length > 0) {
    console.log('\nApplying updates...');
    for (const update of updates) {
      await update.ref.update({ [update.field]: update.value });
      console.log(`Updated ${update.ref.id}: ${update.field}`);
    }
    console.log('\nAll updates applied!');
  } else {
    console.log('\nNo updates needed.');
  }

  process.exit(0);
}

auditMathImages().catch(e => { console.error(e); process.exit(1); });
