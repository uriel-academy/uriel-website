// Upload English JHS 1 course units to Firestore
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function uploadCourse() {
  try {
    console.log('🚀 Starting English JHS 1 course upload...\n');

    // Read index file
    const indexPath = path.join(__dirname, 'assets', 'English_JHS_1', 'index_english_jhs_1.json');
    const indexData = JSON.parse(fs.readFileSync(indexPath, 'utf8'));

    // Create/update course document
    const courseRef = db.collection('courses').doc(indexData.course_id);
    await courseRef.set({
      title: indexData.title,
      description: indexData.description,
      version: indexData.version,
      last_updated_utc: admin.firestore.Timestamp.now(),
      total_units: indexData.units.length,
      subject: 'English',
      level: 'JHS 1',
      cover_image_url: null, // Add later if needed
    });

    console.log(`✅ Course document created: ${indexData.course_id}`);
    console.log(`   Title: ${indexData.title}`);
    console.log(`   Total Units: ${indexData.units.length}\n`);

    // Upload each unit
    for (const unitInfo of indexData.units) {
      // Fix filename mismatch: index has b7, actual files have jhs_1
      const actualFilename = unitInfo.file.replace('english_b7', 'english_jhs_1');
      const unitFilePath = path.join(
        __dirname,
        'assets',
        'English_JHS_1',
        actualFilename
      );

      if (!fs.existsSync(unitFilePath)) {
        console.log(`⚠️  File not found: ${actualFilename} (original: ${unitInfo.file})`);
        continue;
      }

      const unitFileData = JSON.parse(fs.readFileSync(unitFilePath, 'utf8'));
      const unitData = unitFileData.unit;

      // Upload to Firestore
      const unitRef = courseRef.collection('units').doc(unitData.unit_id);
      await unitRef.set(unitData);

      console.log(`✅ Unit uploaded: ${unitData.unit_id}`);
      console.log(`   Title: ${unitData.title}`);
      console.log(`   Lessons: ${unitData.lessons.length}`);
      console.log(`   Total XP: ${unitData.xp_total}`);
      console.log(`   Duration: ${unitData.estimated_duration_min} min\n`);
    }

    console.log('🎉 Upload complete!\n');
    console.log('📊 Summary:');
    console.log(`   Course: ${indexData.title}`);
    console.log(`   Units uploaded: ${indexData.units.length}`);
    console.log('\n✨ Students can now access the course in the app!');

  } catch (error) {
    console.error('❌ Error uploading course:', error);
  } finally {
    process.exit(0);
  }
}

// Run upload
uploadCourse();
