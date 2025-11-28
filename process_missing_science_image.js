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

async function processSingleImage() {
    const filename = 'q39_optionB_science_2010_img2.png';
    const inputDir = 'assets/science_images';
    const outputDir = 'assets/science_images_webp';
    
    console.log(`Processing: ${filename}`);
    
    // Convert to WebP
    const inputPath = path.join(inputDir, filename);
    const webpFilename = 'q39_optionB_science_2010_img2.webp';
    const outputPath = path.join(outputDir, webpFilename);
    
    await sharp(inputPath)
        .webp({ quality: 85, effort: 4 })
        .toFile(outputPath);
    
    console.log('  ✓ Converted to WebP');
    
    // Upload to Storage
    const storagePath = `science_images/${webpFilename}`;
    await bucket.upload(outputPath, {
        destination: storagePath,
        metadata: {
            cacheControl: 'public, max-age=31536000',
        }
    });
    
    await bucket.file(storagePath).makePublic();
    const imageUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    
    console.log(`  ✓ Uploaded: ${imageUrl}`);
    
    // Link to Firestore
    const snapshot = await db.collection('questions')
        .where('subject', '==', 'integratedScience')
        .where('year', '==', '2010')
        .where('questionNumber', '==', 39)
        .where('type', '==', 'multipleChoice')
        .limit(1)
        .get();
    
    const doc = snapshot.docs[0];
    const currentData = doc.data();
    
    await doc.ref.update({
        imageUrls: [...(currentData.imageUrls || []), imageUrl],
        hasImage: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('  ✓ Linked to integratedScience 2010 Q39');
    console.log('\nDone!');
    
    process.exit(0);
}

processSingleImage().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
