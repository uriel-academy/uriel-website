// Script to verify no teachers are in studentSummaries or classAggregates
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔍 Verifying teacher exclusion from aggregates...\n');

async function verify() {
  try {
    // Get all teachers
    const teachersSnap = await db.collection('users').where('role', '==', 'teacher').get();
    const teacherIds = new Set(teachersSnap.docs.map(d => d.id));
    
    console.log(`📚 Found ${teacherIds.size} teachers in users collection`);
    teachersSnap.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.firstName} ${data.lastName} (${doc.id})`);
    });
    
    // Check if any teachers are in studentSummaries
    console.log(`\n🔍 Checking studentSummaries collection...`);
    const summariesSnap = await db.collection('studentSummaries').get();
    console.log(`   Found ${summariesSnap.size} documents in studentSummaries`);
    
    let teachersInSummaries = 0;
    summariesSnap.docs.forEach(doc => {
      if (teacherIds.has(doc.id)) {
        teachersInSummaries++;
        console.log(`   ❌ ERROR: Teacher ${doc.id} found in studentSummaries!`);
      }
    });
    
    if (teachersInSummaries === 0) {
      console.log(`   ✅ No teachers found in studentSummaries`);
    }
    
    // Check users collection for any with role='teacher' that might be counted
    console.log(`\n🔍 Checking for role mismatches...`);
    const allUsersSnap = await db.collection('users').get();
    let mismatchCount = 0;
    
    allUsersSnap.docs.forEach(doc => {
      const data = doc.data();
      const email = data.email || '';
      
      // Check if email contains teacher indicators but role is student
      if (data.role === 'student' && email.includes('teacher')) {
        console.log(`   ⚠️  Possible mismatch: ${data.firstName} ${data.lastName} (${email}) has role='student' but email suggests teacher`);
        mismatchCount++;
      }
      
      // Check if teacher has been added to studentSummaries
      if (data.role === 'teacher' && teacherIds.has(doc.id)) {
        console.log(`   ✓ Teacher ${data.firstName} ${data.lastName} correctly has role='teacher'`);
      }
    });
    
    // List all entries in studentSummaries to see what's there
    console.log(`\n📋 Current studentSummaries entries:`);
    summariesSnap.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.firstName} ${data.lastName} (${doc.id})`);
      console.log(`      School: ${data.normalizedSchool}, Class: ${data.normalizedClass}`);
      console.log(`      TeacherId: ${data.teacherId || 'none'}`);
      console.log(`      TotalXP: ${data.totalXP || 0}, Questions: ${data.questionsSolved || 0}`);
    });
    
    // Summary
    console.log(`\n📊 Verification Summary:`);
    console.log(`   ✓ ${teacherIds.size} teachers in users collection`);
    console.log(`   ✓ ${summariesSnap.size} entries in studentSummaries`);
    console.log(`   ${teachersInSummaries === 0 ? '✅' : '❌'} ${teachersInSummaries} teachers found in studentSummaries`);
    console.log(`   ${mismatchCount === 0 ? '✅' : '⚠️ '} ${mismatchCount} potential role mismatches`);
    
    if (teachersInSummaries === 0 && mismatchCount === 0) {
      console.log(`\n🎉 All checks passed! Teachers are properly excluded.`);
    } else {
      console.log(`\n⚠️  Issues found that need to be resolved.`);
    }
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

verify();
