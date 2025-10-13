const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function extractEpubCover(epubPath) {
  try {
    const zip = new AdmZip(epubPath);
    const zipEntries = zip.getEntries();
    
    // Look for common cover image patterns
    const coverPatterns = [
      /cover\.(jpg|jpeg|png|gif)/i,
      /cover[-_]?image\.(jpg|jpeg|png|gif)/i,
      /cover[-_]?page\.(jpg|jpeg|png|gif)/i,
      /title[-_]?page\.(jpg|jpeg|png|gif)/i,
      /OEBPS\/images\/cover\.(jpg|jpeg|png|gif)/i,
      /OEBPS\/cover\.(jpg|jpeg|png|gif)/i,
      /images\/cover\.(jpg|jpeg|png|gif)/i,
      /^cover\.(jpg|jpeg|png|gif)/i,
    ];
    
    // First, try to find cover in container.xml or content.opf
    let coverImagePath = null;
    
    // Check container.xml for content.opf location
    const containerEntry = zipEntries.find(e => e.entryName.includes('container.xml'));
    if (containerEntry) {
      const containerXml = containerEntry.getData().toString('utf8');
      const opfMatch = containerXml.match(/full-path="([^"]+\.opf)"/);
      
      if (opfMatch) {
        const opfPath = opfMatch[1];
        const opfEntry = zipEntries.find(e => e.entryName === opfPath);
        
        if (opfEntry) {
          const opfXml = opfEntry.getData().toString('utf8');
          
          // Look for cover reference in metadata
          const coverIdMatch = opfXml.match(/name="cover"\s+content="([^"]+)"/i);
          if (coverIdMatch) {
            const coverId = coverIdMatch[1];
            const coverHrefMatch = opfXml.match(new RegExp(`id="${coverId}"[^>]*href="([^"]+)"`, 'i'));
            if (coverHrefMatch) {
              const opfDir = path.dirname(opfPath);
              coverImagePath = path.join(opfDir, coverHrefMatch[1]).replace(/\\/g, '/');
            }
          }
          
          // Alternative: look for item with properties="cover-image"
          if (!coverImagePath) {
            const coverItemMatch = opfXml.match(/properties="cover-image"[^>]*href="([^"]+)"/i);
            if (coverItemMatch) {
              const opfDir = path.dirname(opfPath);
              coverImagePath = path.join(opfDir, coverItemMatch[1]).replace(/\\/g, '/');
            }
          }
        }
      }
    }
    
    // If we found a cover path from metadata, try to extract it
    if (coverImagePath) {
      const coverEntry = zipEntries.find(e => e.entryName === coverImagePath);
      if (coverEntry) {
        return { data: coverEntry.getData(), path: coverImagePath };
      }
    }
    
    // Fallback: search for cover by filename patterns
    for (const pattern of coverPatterns) {
      const coverEntry = zipEntries.find(e => pattern.test(e.entryName));
      if (coverEntry && !coverEntry.isDirectory) {
        return { data: coverEntry.getData(), path: coverEntry.entryName };
      }
    }
    
    // Last resort: find any image in the root or images folder
    const imageEntry = zipEntries.find(e => {
      const isImage = /\.(jpg|jpeg|png|gif)$/i.test(e.entryName);
      const isInRootOrImages = e.entryName.split('/').length <= 2 || e.entryName.includes('images');
      return isImage && isInRootOrImages && !e.isDirectory;
    });
    
    if (imageEntry) {
      return { data: imageEntry.getData(), path: imageEntry.entryName };
    }
    
    return null;
  } catch (error) {
    console.error(`Error extracting cover from EPUB:`, error.message);
    return null;
  }
}

async function extractAndSaveCovers() {
  const storybooksDir = path.join(__dirname, 'assets', 'storybooks');
  const coversDir = path.join(__dirname, 'assets', 'storybook_covers');
  
  // Create covers directory if it doesn't exist
  if (!fs.existsSync(coversDir)) {
    fs.mkdirSync(coversDir, { recursive: true });
  }
  
  // Get all storybooks from Firestore
  const storybooksSnapshot = await db.collection('storybooks').get();
  
  console.log(`Found ${storybooksSnapshot.size} storybooks in Firestore`);
  console.log(`Cover images will be saved to: ${coversDir}`);
  console.log('Starting cover extraction...\n');
  
  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  
  for (const doc of storybooksSnapshot.docs) {
    const book = doc.data();
    
    // Skip if not an EPUB file
    if (book.format !== 'epub') {
      console.log(`⏭️  Skipping ${book.title} (not EPUB format)`);
      skippedCount++;
      continue;
    }
    
    console.log(`\n📚 Processing: ${book.title} by ${book.author}`);
    
    try {
      const epubPath = path.join(storybooksDir, book.fileName);
      
      // Extract cover from EPUB
      console.log(`   🔍 Extracting cover from EPUB...`);
      const coverResult = await extractEpubCover(epubPath);
      
      if (!coverResult) {
        console.log(`   ⚠️  No cover found in EPUB`);
        errorCount++;
        continue;
      }
      
      const coverData = coverResult.data;
      console.log(`   ✅ Cover extracted (${(coverData.length / 1024).toFixed(1)} KB)`);
      
      // Determine file extension
      let ext = 'jpg';
      if (coverData[0] === 0x89 && coverData[1] === 0x50) {
        ext = 'png';
      } else if (coverData[0] === 0x47 && coverData[1] === 0x49) {
        ext = 'gif';
      }
      
      // Save cover to local file
      const coverFileName = `${book.id}.${ext}`;
      const coverFilePath = path.join(coversDir, coverFileName);
      fs.writeFileSync(coverFilePath, coverData);
      
      console.log(`   💾 Saved to: assets/storybook_covers/${coverFileName}`);
      
      // Update Firestore with local asset path
      const coverAssetPath = `assets/storybook_covers/${coverFileName}`;
      await db.collection('storybooks').doc(doc.id).update({
        coverImageUrl: coverAssetPath,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`   ✅ Firestore updated with asset path`);
      successCount++;
      
    } catch (error) {
      console.error(`   ❌ Error processing ${book.title}:`, error.message);
      errorCount++;
    }
  }
  
  console.log('\n' + '='.repeat(70));
  console.log(`📊 Cover Extraction Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${errorCount}`);
  console.log(`   ⏭️  Skipped: ${skippedCount}`);
  console.log(`   📚 Total: ${storybooksSnapshot.size}`);
  console.log('='.repeat(70));
  console.log(`\n📁 Cover images saved to: ${coversDir}`);
  console.log(`\n⚠️  IMPORTANT: Add "assets/storybook_covers/" to pubspec.yaml assets section`);
}

// Run the extraction
extractAndSaveCovers()
  .then(() => {
    console.log('\n✨ Cover extraction complete!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Fatal error:', error);
    process.exit(1);
  });
