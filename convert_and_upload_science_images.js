const admin = require('firebase-admin');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

/**
 * Parse image filename to extract metadata
 * Formats:
 * - q11_science_2002_img1.png -> Q11, 2002
 * - q5_optionA_science_2005_img1.png -> Q5, 2005 (for option images)
 */
function parseImageFilename(filename) {
    const match = filename.match(/^q(\d+)(?:_option([A-D]))?_science_(\d{4})_img(\d+)\.(png|jpg|jpeg)$/i);
    
    if (!match) {
        console.warn(`  ⚠️  Could not parse filename: ${filename}`);
        return null;
    }
    
    return {
        questionNumber: parseInt(match[1]),
        option: match[2] || null, // A, B, C, D or null
        year: match[3],
        imageIndex: parseInt(match[4]),
        extension: match[5]
    };
}

/**
 * Convert image to WebP format
 */
async function convertToWebP(inputPath, outputPath) {
    try {
        await sharp(inputPath)
            .webp({ quality: 85, effort: 4 })
            .toFile(outputPath);
        return true;
    } catch (error) {
        console.error(`Error converting ${inputPath}:`, error.message);
        return false;
    }
}

/**
 * Upload image to Firebase Storage and make it public
 */
async function uploadToStorage(localPath, storagePath) {
    try {
        await bucket.upload(localPath, {
            destination: storagePath,
            metadata: {
                cacheControl: 'public, max-age=31536000', // 1 year cache
            }
        });
        
        // Make the file public
        await bucket.file(storagePath).makePublic();
        
        // Get public URL
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        return publicUrl;
    } catch (error) {
        console.error(`Error uploading ${localPath}:`, error.message);
        return null;
    }
}

/**
 * Link image to Firestore question
 */
async function linkImageToQuestion(subject, year, questionNumber, imageUrl, isOptionImage = false) {
    try {
        // Query for the specific question
        const snapshot = await db.collection('questions')
            .where('subject', '==', subject)
            .where('year', '==', year)
            .where('questionNumber', '==', questionNumber)
            .where('type', '==', 'multipleChoice')
            .limit(1)
            .get();
        
        if (snapshot.empty) {
            console.warn(`  ⚠️  Question not found: ${subject} ${year} Q${questionNumber}`);
            return false;
        }
        
        const doc = snapshot.docs[0];
        const currentData = doc.data();
        
        // Build update data
        const updateData = {
            hasImage: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        // Handle multiple images per question
        if (currentData.imageUrls && Array.isArray(currentData.imageUrls)) {
            // Add to existing array
            updateData.imageUrls = [...currentData.imageUrls, imageUrl];
        } else if (currentData.imageUrl) {
            // Convert single to array
            updateData.imageUrls = [currentData.imageUrl, imageUrl];
        } else {
            // First image
            updateData.imageUrl = imageUrl;
            updateData.imageUrls = [imageUrl];
        }
        
        await doc.ref.update(updateData);
        return true;
    } catch (error) {
        console.error(`Error linking image to question:`, error.message);
        return false;
    }
}

/**
 * Main processing function
 */
async function processAllImages() {
    console.log('=== INTEGRATED SCIENCE IMAGE PROCESSING ===\n');
    
    const inputDir = 'assets/science_images';
    const outputDir = 'assets/science_images_webp';
    
    // Create output directory
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Get all image files
    const files = fs.readdirSync(inputDir)
        .filter(f => /\.(png|jpg|jpeg)$/i.test(f));
    
    console.log(`Found ${files.length} images to process\n`);
    
    const stats = {
        totalImages: files.length,
        converted: 0,
        uploaded: 0,
        linked: 0,
        errors: []
    };
    
    // Process each image
    for (const filename of files) {
        console.log(`Processing: ${filename}`);
        
        // Parse filename
        const metadata = parseImageFilename(filename);
        if (!metadata) {
            stats.errors.push({ filename, error: 'Could not parse filename' });
            continue;
        }
        
        const { questionNumber, option, year, imageIndex } = metadata;
        
        // Convert to WebP
        const inputPath = path.join(inputDir, filename);
        const webpFilename = filename.replace(/\.(png|jpg|jpeg)$/i, '.webp');
        const outputPath = path.join(outputDir, webpFilename);
        
        console.log(`  Converting to WebP...`);
        const converted = await convertToWebP(inputPath, outputPath);
        if (!converted) {
            stats.errors.push({ filename, error: 'Conversion failed' });
            continue;
        }
        stats.converted++;
        
        // Upload to Firebase Storage
        const storagePath = `science_images/${webpFilename}`;
        console.log(`  Uploading to Storage...`);
        const imageUrl = await uploadToStorage(outputPath, storagePath);
        if (!imageUrl) {
            stats.errors.push({ filename, error: 'Upload failed' });
            continue;
        }
        stats.uploaded++;
        console.log(`  ✓ Uploaded: ${imageUrl}`);
        
        // Link to Firestore question
        console.log(`  Linking to Question ${questionNumber} (${year})...`);
        const linked = await linkImageToQuestion(
            'integratedScience',
            year,
            questionNumber,
            imageUrl,
            option !== null
        );
        
        if (linked) {
            stats.linked++;
            console.log(`  ✓ Linked to integratedScience ${year} Q${questionNumber}`);
        }
        
        console.log();
    }
    
    // Summary
    console.log('\n=== PROCESSING COMPLETE ===');
    console.log(`Total images: ${stats.totalImages}`);
    console.log(`Converted to WebP: ${stats.converted}`);
    console.log(`Uploaded to Storage: ${stats.uploaded}`);
    console.log(`Linked to Firestore: ${stats.linked}`);
    console.log(`Errors: ${stats.errors.length}`);
    
    if (stats.errors.length > 0) {
        console.log('\nErrors:');
        stats.errors.forEach(e => {
            console.log(`  - ${e.filename}: ${e.error}`);
        });
    }
    
    // Save report
    const report = {
        ...stats,
        processedAt: new Date().toISOString()
    };
    
    fs.writeFileSync(
        'science_images_processing_report.json',
        JSON.stringify(report, null, 2)
    );
    
    console.log('\nReport saved to: science_images_processing_report.json');
    
    process.exit(0);
}

// Run
processAllImages().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});
