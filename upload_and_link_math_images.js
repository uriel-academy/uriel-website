const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
  });
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

async function uploadImagesAndLinkToQuestions() {
  console.log('Starting image upload and linking process...\n');
  
  // Read the image mapping
  const mappingFile = 'assets/mathematics_images/image_mapping.json';
  if (!fs.existsSync(mappingFile)) {
    console.error('Image mapping file not found!');
    process.exit(1);
  }
  
  const imageMapping = JSON.parse(fs.readFileSync(mappingFile, 'utf8'));
  
  let totalUploaded = 0;
  let totalLinked = 0;
  let errors = 0;
  
  // Process each year
  for (const year of Object.keys(imageMapping).sort()) {
    console.log(`\nProcessing ${year}...`);
    const yearMapping = imageMapping[year];
    
    for (const questionNum of Object.keys(yearMapping)) {
      const imageFiles = yearMapping[questionNum];
      
      try {
        // Find the question in Firestore
        const querySnapshot = await db.collection('questions')
          .where('subject', '==', 'mathematics')
          .where('year', '==', year)
          .where('questionNumber', '==', parseInt(questionNum))
          .limit(1)
          .get();
        
        if (querySnapshot.empty) {
          console.log(`  ⚠ Q${questionNum} not found in database`);
          continue;
        }
        
        const questionDoc = querySnapshot.docs[0];
        
        // Upload images to Firebase Storage
        const uploadedUrls = [];
        
        for (const imageFile of imageFiles) {
          const localPath = path.join('assets/mathematics_images', imageFile);
          
          if (!fs.existsSync(localPath)) {
            console.log(`  ⚠ Image file not found: ${imageFile}`);
            continue;
          }
          
          // Upload to Storage
          const storagePath = `mathematics_images/${imageFile}`;
          const file = bucket.file(storagePath);
          
          await file.save(fs.readFileSync(localPath), {
            metadata: {
              contentType: imageFile.endsWith('.png') ? 'image/png' : 'image/jpeg',
              metadata: {
                year: year,
                questionNumber: questionNum
              }
            }
          });
          
          // Make public
          await file.makePublic();
          
          // Get public URL
          const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
          uploadedUrls.push(publicUrl);
          totalUploaded++;
        }
        
        if (uploadedUrls.length > 0) {
          // Update question with image URL(s)
          const updateData = {
            imageBeforeQuestion: uploadedUrls[0], // Primary image
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          };
          
          // If multiple images, store additional ones
          if (uploadedUrls.length > 1) {
            updateData.additionalImages = uploadedUrls;
          }
          
          await questionDoc.ref.update(updateData);
          
          console.log(`  ✅ Q${questionNum}: Uploaded and linked ${uploadedUrls.length} image(s)`);
          totalLinked++;
        }
        
      } catch (error) {
        console.error(`  ❌ Error processing Q${questionNum}:`, error.message);
        errors++;
      }
    }
  }
  
  console.log('\n' + '='.repeat(50));
  console.log(`Total images uploaded: ${totalUploaded}`);
  console.log(`Total questions linked: ${totalLinked}`);
  console.log(`Errors: ${errors}`);
  console.log('='.repeat(50));
}

uploadImagesAndLinkToQuestions()
  .then(() => {
    console.log('\n✅ Image upload and linking completed!');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n❌ Fatal error:', err);
    process.exit(1);
  });
