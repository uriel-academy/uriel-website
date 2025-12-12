const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(process.cwd(), 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (fs.existsSync(serviceAccountPath)) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.appspot.com'
  });
} else {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    storageBucket: 'uriel-academy-41fb0.appspot.com'
  });
}

const bucket = admin.storage().bucket();
const db = admin.firestore();

// Directories
const GENERATED_SECTIONS_DIR = path.join(__dirname, '..', 'generated_sections');
const TEXTBOOKS_DIR = path.join(__dirname, '..', 'assets', 'textbooks');

async function uploadMarkdownFiles() {
  console.log('📁 Starting markdown files upload to Firebase Storage...\n');
  
  try {
    const files = fs.readdirSync(GENERATED_SECTIONS_DIR);
    const markdownFiles = files.filter(f => f.endsWith('.md'));
    
    console.log(`Found ${markdownFiles.length} markdown files\n`);
    
    let uploadedCount = 0;
    let errorCount = 0;
    
    for (const filename of markdownFiles) {
      try {
        const filePath = path.join(GENERATED_SECTIONS_DIR, filename);
        const content = fs.readFileSync(filePath, 'utf8');
        
        // Upload to Firebase Storage: textbooks/generated_sections/{filename}
        const destination = `textbooks/generated_sections/${filename}`;
        const file = bucket.file(destination);
        
        await file.save(content, {
          metadata: {
            contentType: 'text/markdown',
            metadata: {
              uploadedAt: new Date().toISOString(),
              source: 'AI_generated'
            }
          }
        });
        
        uploadedCount++;
        if (uploadedCount % 50 === 0) {
          console.log(`✅ Uploaded ${uploadedCount}/${markdownFiles.length} files...`);
        }
        
      } catch (error) {
        console.error(`❌ Error uploading ${filename}:`, error.message);
        errorCount++;
      }
    }
    
    console.log(`\n✅ Upload complete!`);
    console.log(`   - Uploaded: ${uploadedCount}`);
    console.log(`   - Errors: ${errorCount}`);
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

async function saveMarkdownSectionsToFirestore() {
  console.log('\n📋 Saving markdown sections to Firestore...\n');
  
  try {
    const files = fs.readdirSync(GENERATED_SECTIONS_DIR);
    const markdownFiles = files.filter(f => f.endsWith('.md'));
    
    console.log(`Found ${markdownFiles.length} markdown files to save to Firestore\n`);
    
    let savedCount = 0;
    let errorCount = 0;
    let batchCount = 0;
    let batch = db.batch();
    
    for (const filename of markdownFiles) {
      try {
        const filePath = path.join(GENERATED_SECTIONS_DIR, filename);
        const content = fs.readFileSync(filePath, 'utf8');
        
        // Parse filename to extract metadata
        // Example: science_jhs1_ch1_sec1_the_scientific_method.md
        const parts = filename.replace('.md', '').split('_');
        const subject = parts[0];
        const yearMatch = parts[1].match(/(jhs|shs)(\d)/i);
        const year = yearMatch ? `${yearMatch[1].toUpperCase()} ${yearMatch[2]}` : 'Unknown';
        
        // Extract chapter and section numbers
        const chapterMatch = filename.match(/ch(\d+)/);
        const sectionMatch = filename.match(/sec(\d+)/);
        const chapterNum = chapterMatch ? parseInt(chapterMatch[1]) : 0;
        const sectionNum = sectionMatch ? parseInt(sectionMatch[1]) : 0;
        
        // Create document ID from filename
        const docId = filename.replace('.md', '');
        const docRef = db.collection('textbook_sections_markdown').doc(docId);
        
        batch.set(docRef, {
          id: docId,
          subject: subject,
          year: year,
          chapterNumber: chapterNum,
          sectionNumber: sectionNum,
          content: content,
          filename: filename,
          storageUrl: `textbooks/generated_sections/${filename}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        savedCount++;
        batchCount++;
        
        // Commit in batches of 500 (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`✅ Committed ${savedCount}/${markdownFiles.length} sections...`);
          batch = db.batch();
          batchCount = 0;
        }
        
      } catch (error) {
        console.error(`❌ Error saving ${filename}:`, error.message);
        errorCount++;
      }
    }
    
    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`\n✅ Firestore save complete!`);
    console.log(`   - Saved: ${savedCount}`);
    console.log(`   - Errors: ${errorCount}`);
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

async function main() {
  console.log('🚀 Starting textbook backup to Firebase...\n');
  console.log('═══════════════════════════════════════════════\n');
  
  // Upload markdown sections to Storage
  await uploadMarkdownFiles();
  
  // Save markdown sections to Firestore
  await saveMarkdownSectionsToFirestore();
  
  console.log('\n═══════════════════════════════════════════════');
  console.log('✅ All markdown files backed up to Firebase!');
  console.log('   Storage: textbooks/generated_sections/');
  console.log('   Firestore: textbook_sections_markdown collection');
  console.log('═══════════════════════════════════════════════\n');
  
  process.exit(0);
}

main();
