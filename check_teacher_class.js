// Script to check and fix teacher's class field
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🔍 Checking teacher data...\n');

// Normalization function
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

async function checkTeacher() {
  try {
    const teachersSnap = await db.collection('users').where('role', '==', 'teacher').get();
    
    console.log(`📚 Found ${teachersSnap.size} teacher(s):\n`);
    
    for (const doc of teachersSnap.docs) {
      const data = doc.data();
      const teacherId = doc.id;
      const school = data.school || data.schoolName;
      const cls = data.class || data.teachingGrade;
      
      console.log(`Teacher: ${data.firstName} ${data.lastName} (${teacherId})`);
      console.log(`  School (raw): "${school}"`);
      console.log(`  School (normalized): "${normalizeSchoolClass(school)}"`);
      console.log(`  Class (raw): "${cls}"`);
      console.log(`  Class (normalized): "${normalizeSchoolClass(cls)}"`);
      console.log(`  Expected classId: ${normalizeSchoolClass(school)}_${normalizeSchoolClass(cls)}`);
      
      // Check if we need to update the teacher's class field
      const normalizedClass = normalizeSchoolClass(cls);
      if (normalizedClass !== '1') {
        console.log(`\n  ⚠️  Teacher's class normalizes to "${normalizedClass}" but should normalize to "1"`);
        console.log(`  💡 Suggestion: Update teacher's class to "JHS FORM 1" so it normalizes correctly`);
      }
      
      console.log();
    }
    
    // Check students
    console.log('📊 Checking students:\n');
    const studentsSnap = await db.collection('studentSummaries').get();
    
    for (const doc of studentsSnap.docs) {
      const data = doc.data();
      console.log(`Student: ${data.firstName} ${data.lastName}`);
      console.log(`  normalizedSchool: "${data.normalizedSchool}"`);
      console.log(`  normalizedClass: "${data.normalizedClass}"`);
      console.log(`  Expected classId: ${data.normalizedSchool}_${data.normalizedClass}\n`);
    }
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR:', e);
    process.exit(1);
  }
}

checkTeacher();
