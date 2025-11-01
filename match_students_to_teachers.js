// Script to match existing students to their teachers based on school and class
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔗 Matching students to teachers based on school and class...\n');

// Normalization function (must match Cloud Functions)
function normalizeSchoolClass(raw) {
  if (!raw) return null;
  let s = String(raw).toLowerCase();
  const noise = ['school', 'college', 'high', 'senior', 'basic', 'jhs', 'shs', 'form', 'the'];
  for (const n of noise) {
    s = s.replace(new RegExp(`\\b${n}\\b`, 'gi'), '');
  }
  s = s.replace(/[^a-z0-9]+/g, ' ').trim().replace(/\s+/g, '_');
  return s || null;
}

async function matchStudentsToTeachers() {
  try {
    // First, get all teachers with their school and class
    const teachersSnap = await db.collection('users').where('role', '==', 'teacher').get();
    const teachersMap = new Map();
    
    console.log(`📚 Found ${teachersSnap.size} teachers`);
    
    for (const doc of teachersSnap.docs) {
      const data = doc.data();
      const school = data.school || data.schoolName || '';
      const cls = data.class || data.teachingGrade || '';
      
      if (!school || !cls) {
        console.log(`   ⚠️  Teacher ${doc.id} (${data.firstName} ${data.lastName}) missing school or class`);
        continue;
      }
      
      const normSchool = normalizeSchoolClass(school);
      const normClass = normalizeSchoolClass(cls);
      const key = `${normSchool}_${normClass}`;
      
      teachersMap.set(key, {
        id: doc.id,
        name: `${data.firstName || ''} ${data.lastName || ''}`.trim(),
        school: school,
        class: cls,
        normSchool,
        normClass
      });
      
      console.log(`   ✓ Teacher: ${data.firstName} ${data.lastName}`);
      console.log(`      School: "${school}" → normalized: "${normSchool}"`);
      console.log(`      Class: "${cls}" → normalized: "${normClass}"`);
    }
    
    console.log(`\n👥 Matching students...`);
    
    // Now get all students and match them
    const studentsSnap = await db.collection('users').where('role', '==', 'student').get();
    let matchedCount = 0;
    let unmatchedCount = 0;
    
    const batch = db.batch();
    let batchCount = 0;
    const maxBatchSize = 500;
    
    for (const doc of studentsSnap.docs) {
      const data = doc.data();
      const school = data.school || data.schoolName || '';
      const cls = data.class || data.grade || '';
      
      if (!school || !cls) {
        console.log(`   ⚠️  Student ${doc.id} missing school or class`);
        unmatchedCount++;
        continue;
      }
      
      const normSchool = normalizeSchoolClass(school);
      const normClass = normalizeSchoolClass(cls);
      const key = `${normSchool}_${normClass}`;
      
      const teacher = teachersMap.get(key);
      
      if (teacher) {
        // Match found!
        batch.update(doc.ref, { teacherId: teacher.id });
        batchCount++;
        matchedCount++;
        console.log(`   ✓ Matched: ${data.firstName} ${data.lastName}`);
        console.log(`      Student: "${school}" + "${cls}" → "${key}"`);
        console.log(`      Teacher: ${teacher.name} (${teacher.school} + ${teacher.class})`);
        
        // Commit batch if it reaches max size
        if (batchCount >= maxBatchSize) {
          await batch.commit();
          console.log(`   💾 Committed batch of ${batchCount} updates`);
          batchCount = 0;
        }
      } else {
        console.log(`   ✗ No teacher found for: ${data.firstName} ${data.lastName}`);
        console.log(`      School: "${school}" → normalized: "${normSchool}"`);
        console.log(`      Class: "${cls}" → normalized: "${normClass}"`);
        console.log(`      Looking for key: "${key}"`);
        unmatchedCount++;
      }
    }
    
    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   💾 Committed final batch of ${batchCount} updates`);
    }
    
    console.log(`\n🎉 Matching completed!`);
    console.log(`   ✓ ${matchedCount} students matched to teachers`);
    console.log(`   ✗ ${unmatchedCount} students without matching teacher`);
    console.log(`\n📝 Next steps:`);
    console.log(`   1. Teachers should update their profiles with correct school/class`);
    console.log(`   2. Students should update their profiles with correct school/class`);
    console.log(`   3. Run backfill to update studentSummaries with teacherId`);
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

matchStudentsToTeachers();
