const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.appspot.com'
});

const bucket = admin.storage().bucket();
const db = admin.firestore();

async function uploadStorybooksToStorage() {
  const storybooksDir = path.join(__dirname, 'assets', 'storybooks');

  if (!fs.existsSync(storybooksDir)) {
    console.log('Storybooks directory not found. Skipping upload.');
    return;
  }

  const files = fs.readdirSync(storybooksDir);
  console.log(`Found ${files.length} storybook files to upload`);

  for (const file of files) {
    if (!file.endsWith('.epub')) continue;

    const filePath = path.join(storybooksDir, file);
    const storagePath = `storybooks/${file}`;

    try {
      console.log(`Uploading ${file}...`);

      // Upload to Firebase Storage
      await bucket.upload(filePath, {
        destination: storagePath,
        metadata: {
          contentType: 'application/epub+zip',
        },
      });

      // Get download URL
      const fileRef = bucket.file(storagePath);
      const [url] = await fileRef.getSignedUrl({
        action: 'read',
        expires: '2030-01-01', // Long expiration for permanent access
      });

      // Update Firestore document
      const fileNameWithoutExt = file.replace('.epub', '');
      const storybookRef = db.collection('storybooks').doc(fileNameWithoutExt);

      await storybookRef.update({
        storageUrl: url,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Successfully uploaded and updated ${file}`);

    } catch (error) {
      console.error(`❌ Failed to upload ${file}:`, error);
    }
  }

  console.log('🎉 Storybook upload and Firestore update completed!');
}

// Run the upload
uploadStorybooksToStorage().catch(console.error);