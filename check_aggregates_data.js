// Script to check current state of classAggregates and fix the data
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔍 Checking classAggregates and studentSummaries data...\n');

async function checkData() {
  try {
    // Check studentSummaries
    console.log('📊 studentSummaries Collection:');
    const summariesSnap = await db.collection('studentSummaries').get();
    console.log(`   Total documents: ${summariesSnap.size}\n`);
    
    let totalXP = 0;
    summariesSnap.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.firstName} ${data.lastName} (${doc.id})`);
      console.log(`     XP: ${data.totalXP || 0}`);
      console.log(`     School: ${data.normalizedSchool}, Class: ${data.normalizedClass}`);
      console.log(`     TeacherId: ${data.teacherId || 'none'}\n`);
      totalXP += (data.totalXP || 0);
    });
    
    console.log(`   Total XP across all students: ${totalXP}`);
    console.log(`   Average XP: ${summariesSnap.size > 0 ? (totalXP / summariesSnap.size) : 0}\n`);
    
    // Check classAggregates
    console.log('📊 classAggregates Collection:');
    const aggSnap = await db.collection('classAggregates').get();
    console.log(`   Total documents: ${aggSnap.size}\n`);
    
    aggSnap.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   Document ID: ${doc.id}`);
      console.log(`   School: ${data.schoolId} (normalized: ${data.normalizedSchool})`);
      console.log(`   Grade: ${data.grade} (normalized: ${data.normalizedClass})`);
      console.log(`   Total Students: ${data.totalStudents}`);
      console.log(`   Total XP: ${data.totalXP}`);
      console.log(`   Avg XP: ${data.totalStudents > 0 ? (data.totalXP / data.totalStudents) : 0}`);
      console.log(`   Last Updated: ${data.updatedAt?.toDate()}\n`);
    });
    
    // Check for mismatches
    console.log('⚠️  Potential Issues:');
    if (summariesSnap.size !== aggSnap.docs[0]?.data()?.totalStudents) {
      console.log(`   - Mismatch: studentSummaries has ${summariesSnap.size} docs but classAggregates shows ${aggSnap.docs[0]?.data()?.totalStudents} students`);
    }
    
    const expectedAvgXP = summariesSnap.size > 0 ? (totalXP / summariesSnap.size) : 0;
    const actualAvgXP = aggSnap.docs[0]?.data()?.totalStudents > 0 
      ? (aggSnap.docs[0]?.data()?.totalXP / aggSnap.docs[0]?.data()?.totalStudents) 
      : 0;
    
    if (Math.abs(expectedAvgXP - actualAvgXP) > 1) {
      console.log(`   - XP Mismatch: Expected avg ${expectedAvgXP.toFixed(0)}, but classAggregates shows ${actualAvgXP.toFixed(0)}`);
    }
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

checkData();
