const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function importStorybooksMetadata() {
  const storybooksDir = path.join(__dirname, 'assets', 'storybooks');
  const files = fs.readdirSync(storybooksDir);
  
  console.log(`Found ${files.length} storybook files to import metadata...`);
  
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
      
      console.log(`\n📚 Processing: ${file}`);
      
      // Parse book info from filename
      const bookInfo = parseBookInfo(file);
      
      // Store metadata in Firestore
      await db.collection('storybooks').doc(bookInfo.id).set({
        id: bookInfo.id,
        title: bookInfo.title,
        author: bookInfo.author,
        fileName: file,
        assetPath: `assets/storybooks/${file}`, // Path to asset
        fileSize: fileStats.size,
        format: file.endsWith('.epub') ? 'epub' : 'azw3',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        category: 'classic-literature',
        language: 'en',
        readCount: 0,
        isFree: true, // All classics are free
      });
      
      console.log(`✅ Success: ${bookInfo.title} by ${bookInfo.author}`);
      successCount++;
      
    } catch (error) {
      console.error(`❌ Error processing ${file}:`, error.message);
      errorCount++;
    }
  }
  
  console.log('\n' + '='.repeat(60));
  console.log(`📊 Import Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${errorCount}`);
  console.log(`   📚 Total: ${successCount + errorCount}`);
  console.log('='.repeat(60));
}

function parseBookInfo(filename) {
  // Remove file extension
  const nameWithoutExt = filename.replace(/\.(epub|azw3)$/, '');
  
  // Remove numbers in parentheses like (1)
  const cleanName = nameWithoutExt.replace(/\s*\(\d+\)/, '');
  
  // Split by hyphen
  const parts = cleanName.split('-').map(p => p.trim());
  
  // Common author name indicators
  const authorIndicators = ['jr', 'von', 'de', 'le', 'du', 'van', 'st'];
  
  let titleParts = [];
  let authorParts = [];
  
  if (parts.length >= 2) {
    // Last 1-3 parts are likely the author
    let authorStartIndex = parts.length - 2;
    
    // Check for multi-part author names
    for (let i = parts.length - 3; i >= 0 && i < parts.length; i++) {
      if (authorIndicators.some(ind => parts[i].toLowerCase().includes(ind))) {
        authorStartIndex = i;
        break;
      }
    }
    
    // Special handling for known multi-part authors
    if (parts.length >= 3) {
      const lastThree = parts.slice(-3).join(' ').toLowerCase();
      if (lastThree.includes('e b du bois') || lastThree.includes('e m forster') || lastThree.includes('l m montgomery') ||
          lastThree.includes('l frank baum') || lastThree.includes('h g wells') || lastThree.includes('j m barrie') ||
          lastThree.includes('a a milne') || lastThree.includes('f scott fitzgerald')) {
        authorStartIndex = parts.length - 3;
      }
    }
    
    titleParts = parts.slice(0, authorStartIndex);
    authorParts = parts.slice(authorStartIndex);
  } else {
    titleParts = [parts[0] || ''];
    authorParts = parts.slice(1);
  }
  
  // Format title (capitalize each word)
  const title = titleParts
    .join(' ')
    .split(' ')
    .map(word => {
      if (word.toLowerCase() === 'and' || word.toLowerCase() === 'of' || 
          word.toLowerCase() === 'the' || word.toLowerCase() === 'a' || 
          word.toLowerCase() === 'in' || word.toLowerCase() === 'to') {
        return word.toLowerCase();
      }
      return word.charAt(0).toUpperCase() + word.slice(1);
    })
    .join(' ')
    .replace(/^(the|a|an)\s/i, match => match.charAt(0).toUpperCase() + match.slice(1).toLowerCase());
  
  // Format author (capitalize each word)
  const author = authorParts
    .join(' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  
  // Generate ID (lowercase, hyphens)
  const id = cleanName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  
  return { id, title: title || 'Unknown Title', author: author || 'Unknown Author' };
}

// Run the import
importStorybooksMetadata()
  .then(() => {
    console.log('\n✨ All storybook metadata imported successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
