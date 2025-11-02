const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testGetClassAggregatesFunction() {
  console.log('🧪 Testing getClassAggregates Cloud Function\n');
  console.log('='.repeat(80));

  try {
    // Get teacher
    const teachersSnapshot = await db.collection('users')
      .where('role', '==', 'teacher')
      .limit(1)
      .get();

    if (teachersSnapshot.empty) {
      console.log('❌ No teachers found');
      return;
    }

    const teacherId = teachersSnapshot.docs[0].id;
    const teacherData = teachersSnapshot.docs[0].data();

    console.log(`\n👨‍🏫 Teacher: ${teacherData.firstName} ${teacherData.lastName}`);
    console.log(`   Teacher ID: ${teacherId}\n`);

    // Query studentSummaries directly (what the function queries)
    const summariesSnapshot = await db.collection('studentSummaries')
      .where('teacherId', '==', teacherId)
      .orderBy('firstName')
      .limit(50)
      .get();

    console.log(`📊 StudentSummaries Query Result: ${summariesSnapshot.size} documents\n`);

    if (summariesSnapshot.empty) {
      console.log('❌ No student summaries found!');
      console.log('   This is why the teacher dashboard is empty.');
      console.log('   Run: node populate_student_summaries.js\n');
      return;
    }

    summariesSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`${index + 1}. ${data.firstName} ${data.lastName}`);
      console.log(`   - ID: ${doc.id}`);
      console.log(`   - XP: ${data.totalXP || 0}`);
      console.log(`   - Questions: ${data.totalQuestions || 0}`);
      console.log(`   - Subjects: ${data.subjectsCount || 0}`);
      console.log(`   - Accuracy: ${data.avgPercent ? data.avgPercent.toFixed(1) + '%' : 'N/A'}`);
      console.log(`   - Rank: ${data.rank || 'N/A'} (${data.rankName || 'N/A'})`);
      console.log(`   - Email: ${data.email || 'N/A'}`);
      console.log('');
    });

    console.log('='.repeat(80));
    console.log('\n✅ Data exists and is queryable.');
    console.log('   If teacher dashboard is still empty, the issue is in the Flutter app.\n');
    console.log('Next steps:');
    console.log('1. Check browser console for errors');
    console.log('2. Verify teacher is logged in correctly');
    console.log('3. Check Firebase Auth permissions\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testGetClassAggregatesFunction();
