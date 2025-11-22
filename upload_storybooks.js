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

async function uploadStorybooks() {
  const storybooksDir = path.join(__dirname, 'assets', 'storybooks');
  const files = fs.readdirSync(storybooksDir);
  
  console.log(`Found ${files.length} storybook files to upload...`);
  
  let successCount = 0;
  let errorCount = 0;
  
  for (const file of files) {
    try {
      const filePath = path.join(storybooksDir, file);
      const fileStats = fs.statSync(filePath);
      
      // Skip if not a file
      if (!fileStats.isFile()) continue;
      
      // Only process epub and azw3 files
      if (!file.endsWith('.epub') && !file.endsWith('.azw3')) {
        console.log(`⏭️  Skipping non-ebook file: ${file}`);
        continue;
      }
      
      console.log(`\n📤 Uploading: ${file}`);
      
      // Upload to Firebase Storage
      const destination = `storybooks/${file}`;
      await bucket.upload(filePath, {
        destination: destination,
        metadata: {
          contentType: file.endsWith('.epub') ? 'application/epub+zip' : 'application/x-mobipocket-ebook',
          metadata: {
            originalName: file,
            uploadedAt: new Date().toISOString(),
          }
        }
      });
      
      // Make the file publicly readable
      const fileRef = bucket.file(destination);
      await fileRef.makePublic();
      
      // Get the public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;
      
      // Parse book info from filename
      const bookInfo = parseBookInfo(file);
      
      // Store metadata in Firestore
      await db.collection('storybooks').doc(bookInfo.id).set({
        id: bookInfo.id,
        title: bookInfo.title,
        author: bookInfo.author,
        fileName: file,
        fileUrl: publicUrl,
        fileSize: fileStats.size,
        format: file.endsWith('.epub') ? 'epub' : 'azw3',
        uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        category: 'classic-literature',
        language: 'en',
        downloadCount: 0,
      });
      
      console.log(`✅ Success: ${bookInfo.title} by ${bookInfo.author}`);
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
  console.log(`   📚 Total: ${successCount + errorCount}`);
  console.log('='.repeat(60));
}

function parseBookInfo(filename) {
  // Remove file extension
  const nameWithoutExt = filename.replace(/\.(epub|azw3)$/, '');
  
  // Split by last hyphen to separate title and author
  const parts = nameWithoutExt.split('-');
  
  // Find where author name starts (usually last 2-3 parts)
  let titleParts = [];
  let authorParts = [];
  
  // Common author name patterns
  const authorIndicators = ['jr', 'von', 'de', 'le', 'du', 'van'];
  
  // Simple heuristic: last 2-3 parts are likely the author
  // unless we find specific patterns
  if (parts.length > 2) {
    // Look for author indicators
    let authorStartIndex = -1;
    for (let i = parts.length - 3; i < parts.length; i++) {
      if (i >= 0 && authorIndicators.includes(parts[i].toLowerCase())) {
        authorStartIndex = i;
        break;
      }
    }
    
    if (authorStartIndex === -1) {
      // Default: last 2 parts are author
      authorStartIndex = parts.length - 2;
    }
    
    titleParts = parts.slice(0, authorStartIndex);
    authorParts = parts.slice(authorStartIndex);
  } else {
    // If only 2 parts, first is title, last is author
    titleParts = [parts[0]];
    authorParts = parts.slice(1);
  }
  
  // Format title (capitalize each word)
  const title = titleParts
    .join(' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  
  // Format author (capitalize each word)
  const author = authorParts
    .join(' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  
  // Generate ID (lowercase, hyphens)
  const id = nameWithoutExt.toLowerCase().replace(/[^a-z0-9]+/g, '-');
  
  return { id, title, author };
}

// Run the upload
uploadStorybooks()
  .then(() => {
    console.log('\n✨ All storybooks uploaded successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
