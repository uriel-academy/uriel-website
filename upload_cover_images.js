const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const bucket = admin.storage().bucket();
const db = admin.firestore();

async function uploadCoverImages() {
  const coversDir = path.join(__dirname, 'assets', 'storybook_covers');
  const files = fs.readdirSync(coversDir);

  console.log(`Found ${files.length} cover images to upload...`);

  let successCount = 0;
  let errorCount = 0;

  for (const file of files) {
    try {
      const filePath = path.join(coversDir, file);
      const fileStats = fs.statSync(filePath);

      // Skip if not a file
      if (!fileStats.isFile()) continue;

      // Only process image files
      if (!file.endsWith('.jpg') && !file.endsWith('.jpeg') && !file.endsWith('.png')) {
        console.log(`⏭️  Skipping non-image file: ${file}`);
        continue;
      }

      console.log(`\n🖼️  Uploading cover: ${file}`);

      // Upload to Firebase Storage
      const destination = `storybook_covers/${file}`;
      await bucket.upload(filePath, {
        destination: destination,
        metadata: {
          contentType: file.endsWith('.png') ? 'image/png' : 'image/jpeg',
          metadata: {
            originalName: file,
            uploadedAt: new Date().toISOString(),
            type: 'cover_image'
          }
        }
      });

      // Make the image publicly readable
      const fileRef = bucket.file(destination);
      await fileRef.makePublic();

      // Get the public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;

      // Find and update the corresponding storybook document
      const bookFileName = file.replace('.jpg', '.epub').replace('.jpeg', '.epub').replace('.png', '.epub');
      const querySnapshot = await db.collection('storybooks')
        .where('fileName', '==', bookFileName)
        .limit(1)
        .get();

      if (!querySnapshot.empty) {
        const docRef = querySnapshot.docs[0].ref;
        await docRef.update({
          coverImageUrl: publicUrl,
          coverImageStorageUrl: publicUrl, // Keep both for compatibility
        });
        console.log(`✅ Updated Firestore: ${bookFileName}`);
      } else {
        console.log(`⚠️  No matching storybook found for: ${bookFileName}`);
      }

      console.log(`✅ Success: ${file}`);
      console.log(`   URL: ${publicUrl}`);
      successCount++;

    } catch (error) {
      console.error(`❌ Error uploading ${file}:`, error.message);
      errorCount++;
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`📊 Upload Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${errorCount}`);
  console.log(`   🖼️  Total: ${successCount + errorCount}`);
  console.log('='.repeat(60));
}

uploadCoverImages()
  .then(() => {
    console.log('\n✨ All cover images uploaded successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });