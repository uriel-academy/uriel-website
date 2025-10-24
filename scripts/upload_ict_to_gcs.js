// Upload local ICT asset files to the default Firebase storage bucket under `bece_ict/`
// Usage: node scripts/upload_ict_to_gcs.js
// Requires GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account with Storage Admin or Storage Object Creator on the bucket.

const { Storage } = require('@google-cloud/storage');
const path = require('path');
const fs = require('fs');

async function main() {
  const storage = new Storage();
  // If you want to target a specific bucket, set BUCKET env var. Otherwise default bucket from credentials/project will be used.
  const bucketName = process.env.BUCKET || (await storage.getBuckets()).find(b => !!b.name)?.name;
  if (!bucketName) {
    console.error('No bucket found. Set BUCKET env var to target your bucket.');
    process.exit(1);
  }

  const localDir = path.join(__dirname, '..', 'assets', 'bece_ict');
  if (!fs.existsSync(localDir)) {
    console.error('Local assets directory not found:', localDir);
    process.exit(1);
  }

  const files = fs.readdirSync(localDir).filter(f => f.endsWith('.json'));
  if (files.length === 0) {
    console.error('No JSON files found in', localDir);
    process.exit(1);
  }

  const bucket = storage.bucket(bucketName);
  for (const fileName of files) {
    const localPath = path.join(localDir, fileName);
    const destPath = `bece_ict/${fileName}`;
    try {
      await bucket.upload(localPath, { destination: destPath });
      console.log('Uploaded', fileName, '->', `${bucketName}/${destPath}`);
    } catch (err) {
      console.error('Failed to upload', fileName, err && err.message ? err.message : err);
    }
  }

  console.log('Upload complete.');
}

main().catch(err => {
  console.error('Fatal error', err);
  process.exit(1);
});
