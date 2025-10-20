const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.appspot.com'
});

const bucket = admin.storage().bucket();

async function testBucketAccess() {
  try {
    const [files] = await bucket.getFiles({ prefix: 'curriculum/' });
    console.log(`Bucket exists! Found ${files.length} files in curriculum/`);
    return true;
  } catch (error) {
    console.error('Bucket access error:', error.message);
    return false;
  }
}

async function uploadPDFs() {
  const bucketExists = await testBucketAccess();
  if (!bucketExists) {
    console.log('Bucket does not exist or is not accessible. Please check Firebase Storage setup.');
    return;
  }

  const pdfDir = path.join(__dirname, 'assets', 'curriculum', 'jhs curriculum');
  const files = fs.readdirSync(pdfDir).filter(file => file.endsWith('.pdf'));

  console.log(`Found ${files.length} PDF files to upload`);

  for (const file of files) {
    const filePath = path.join(pdfDir, file);
    const storagePath = `curriculum/jhs/${file}`;

    try {
      console.log(`Uploading ${file}...`);
      await bucket.upload(filePath, {
        destination: storagePath,
        metadata: {
          contentType: 'application/pdf',
          metadata: {
            uploadedAt: new Date().toISOString(),
            source: 'jhs_curriculum'
          }
        }
      });
      console.log(`✅ Uploaded ${file} to ${storagePath}`);
    } catch (error) {
      console.error(`❌ Failed to upload ${file}:`, error.message);
    }
  }

  console.log('Upload complete!');
}

// Run the upload
uploadPDFs().catch(console.error);