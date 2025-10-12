// Verify English JHS 1 course upload
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function verifyCourse() {
  try {
    console.log('📊 Verifying English JHS 1 course upload...\n');

    // Get course document
    const courseDoc = await db.collection('courses').doc('english_b7').get();
    
    if (!courseDoc.exists) {
      console.log('❌ Course not found!');
      return;
    }

    const courseData = courseDoc.data();
    console.log('✅ Course Document:');
    console.log(`   ID: english_b7`);
    console.log(`   Title: ${courseData.title}`);
    console.log(`   Description: ${courseData.description}`);
    console.log(`   Total Units: ${courseData.total_units}`);
    console.log(`   Subject: ${courseData.subject}`);
    console.log(`   Level: ${courseData.level}\n`);

    // Get units
    const unitsSnapshot = await db
      .collection('courses')
      .doc('english_b7')
      .collection('units')
      .orderBy('unit_id')
      .get();

    console.log(`📚 Units (${unitsSnapshot.docs.length}):\n`);

    let totalLessons = 0;
    let totalXP = 0;

    unitsSnapshot.docs.forEach((doc, index) => {
      const unit = doc.data();
      totalLessons += unit.lessons.length;
      totalXP += unit.xp_total;
      
      console.log(`${index + 1}. ${unit.title}`);
      console.log(`   ID: ${unit.unit_id}`);
      console.log(`   Lessons: ${unit.lessons.length}`);
      console.log(`   XP: ${unit.xp_total}`);
      console.log(`   Duration: ${unit.estimated_duration_min} min`);
      console.log(`   Competencies: ${unit.competencies.length}`);
      console.log(`   Values/Morals: ${unit.values_morals.length}`);
      
      // Show first lesson as sample
      if (unit.lessons.length > 0) {
        const firstLesson = unit.lessons[0];
        console.log(`   First Lesson: "${firstLesson.title}" (${firstLesson.xp_reward} XP)`);
      }
      console.log('');
    });

    console.log('📈 Summary:');
    console.log(`   Total Units: ${unitsSnapshot.docs.length}`);
    console.log(`   Total Lessons: ${totalLessons}`);
    console.log(`   Total XP Available: ${totalXP}`);
    console.log('\n✨ Course is ready for students!');

  } catch (error) {
    console.error('❌ Error verifying course:', error);
  } finally {
    process.exit(0);
  }
}

verifyCourse();
