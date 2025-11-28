// Convert mathematics images to WebP and upload to Firebase Storage
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize admin (check if already initialized to avoid errors)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
  });
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

const IMAGES_DIR = path.join(__dirname, 'assets', 'mathematics_images');
const WEBP_OUTPUT_DIR = path.join(__dirname, 'assets', 'mathematics_images_webp');
const IMAGE_MAPPING_FILE = path.join(IMAGES_DIR, 'image_mapping.json');

// Statistics
const stats = {
  totalImages: 0,
  converted: 0,
  uploaded: 0,
  linkedToQuestions: 0,
  errors: []
};

// Create output directory
if (!fs.existsSync(WEBP_OUTPUT_DIR)) {
  fs.mkdirSync(WEBP_OUTPUT_DIR, { recursive: true });
}

// Convert image to WebP using Sharp
async function convertToWebP(inputPath, outputPath) {
  try {
    await sharp(inputPath)
      .webp({ quality: 85, effort: 4 }) // Good quality, balanced compression
      .toFile(outputPath);
    return true;
  } catch (error) {
    console.log(`   ⚠️  Could not convert ${path.basename(inputPath)}: ${error.message}`);
    return false;
  }
}

// Upload file to Firebase Storage
async function uploadToStorage(localPath, storagePath) {
  try {
    const destination = `mathematics_images/${storagePath}`;
    await bucket.upload(localPath, {
      destination: destination,
      metadata: {
        contentType: 'image/webp',
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      }
    });
    
    // Get public URL
    const file = bucket.file(destination);
    await file.makePublic();
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;
    
    return publicUrl;
  } catch (error) {
    throw new Error(`Upload failed: ${error.message}`);
  }
}

// Update Firestore question with image URL
async function linkImageToQuestion(year, questionNumber, imageUrls) {
  try {
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .where('year', '==', year)
      .where('questionNumber', '==', questionNumber)
      .where('type', '==', 'multipleChoice')
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      throw new Error(`Question not found: ${year} Q${questionNumber}`);
    }
    
    const doc = snapshot.docs[0];
    await doc.ref.update({
      imageUrl: imageUrls.length === 1 ? imageUrls[0] : imageUrls[0], // Primary image
      imageUrls: imageUrls, // All images array
      hasImage: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return true;
  } catch (error) {
    throw error;
  }
}

async function processImages() {
  console.log('🖼️  MATHEMATICS IMAGES - CONVERSION & UPLOAD\n');
  console.log('='.repeat(80) + '\n');
  
  // Load image mapping
  const imageMapping = JSON.parse(fs.readFileSync(IMAGE_MAPPING_FILE, 'utf8'));
  
  // Count total images
  for (const year in imageMapping) {
    for (const qNum in imageMapping[year]) {
      stats.totalImages += imageMapping[year][qNum].length;
    }
  }
  
  console.log(`📊 Found ${stats.totalImages} images mapped to questions\n`);
  console.log('Starting conversion and upload...\n');
  
  // Process each year
  for (const [year, questions] of Object.entries(imageMapping)) {
    console.log(`\n📅 Processing ${year}...`);
    
    for (const [qNum, imageFiles] of Object.entries(questions)) {
      process.stdout.write(`  Q${qNum.padStart(2, '0')}: `);
      
      const uploadedUrls = [];
      
      for (const imageFile of imageFiles) {
        const inputPath = path.join(IMAGES_DIR, imageFile);
        
        if (!fs.existsSync(inputPath)) {
          console.log(`❌ File not found: ${imageFile}`);
          stats.errors.push({ year, qNum, file: imageFile, error: 'File not found' });
          continue;
        }
        
        try {
          // Determine output format
          const ext = path.extname(imageFile);
          const baseName = path.basename(imageFile, ext);
          const webpFileName = `${baseName}.webp`;
          const webpPath = path.join(WEBP_OUTPUT_DIR, webpFileName);
          
          // Convert to WebP
          const converted = await convertToWebP(inputPath, webpPath);
          
          // Use WebP if conversion succeeded, otherwise use original
          const uploadPath = converted ? webpPath : inputPath;
          const uploadFileName = converted ? webpFileName : imageFile;
          
          if (converted) {
            stats.converted++;
          }
          
          // Upload to Firebase Storage
          const publicUrl = await uploadToStorage(uploadPath, uploadFileName);
          uploadedUrls.push(publicUrl);
          stats.uploaded++;
          
          process.stdout.write('✓');
          
        } catch (error) {
          process.stdout.write('✗');
          console.log(`\n   Error: ${error.message}`);
          stats.errors.push({ year, qNum, file: imageFile, error: error.message });
        }
      }
      
      // Link images to question in Firestore
      if (uploadedUrls.length > 0) {
        try {
          await linkImageToQuestion(year, parseInt(qNum), uploadedUrls);
          stats.linkedToQuestions++;
          console.log(` → Linked (${uploadedUrls.length} image${uploadedUrls.length > 1 ? 's' : ''})`);
        } catch (error) {
          console.log(` → ❌ Link failed: ${error.message}`);
          stats.errors.push({ year, qNum, error: `Link failed: ${error.message}` });
        }
      } else {
        console.log(` → No images uploaded`);
      }
    }
  }
  
  // Print summary
  console.log('\n' + '='.repeat(80));
  console.log('📊 FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log(`Total images: ${stats.totalImages}`);
  console.log(`✅ Converted to WebP: ${stats.converted}`);
  console.log(`✅ Uploaded: ${stats.uploaded}`);
  console.log(`✅ Linked to questions: ${stats.linkedToQuestions}`);
  console.log(`❌ Errors: ${stats.errors.length}`);
  
  if (stats.errors.length > 0) {
    console.log('\n⚠️  Errors encountered:');
    stats.errors.slice(0, 10).forEach(err => {
      console.log(`   - ${err.year} Q${err.qNum}: ${err.error}`);
    });
    if (stats.errors.length > 10) {
      console.log(`   ... and ${stats.errors.length - 10} more`);
    }
  }
  
  if (stats.uploaded === stats.totalImages && stats.linkedToQuestions > 0) {
    console.log('\n✅ SUCCESS: All images converted, uploaded, and linked to questions!');
  }
  
  console.log('\n');
  process.exit(stats.errors.length > 0 ? 1 : 0);
}

// Check if Sharp is available
try {
  const sharpVersion = require('sharp/package.json').version;
  console.log(`✓ Sharp v${sharpVersion} detected - will convert to WebP\n`);
  
  processImages().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
} catch (error) {
  console.error('❌ Sharp library not found. Please run: npm install sharp');
  process.exit(1);
}
