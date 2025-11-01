// Script to run backfillClassAggregates with Firebase Admin SDK authentication
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log('🚀 Starting backfill of student aggregates...');
console.log('📊 This will process all students and create:');
console.log('   - studentSummaries documents (one per student)');
console.log('   - classAggregates documents (one per school/class combination)');
console.log('   ⚠️  Teachers will be EXCLUDED from aggregates\n');

// Normalization function (same as in Cloud Functions)
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

async function runBackfill() {
  try {
    const batchSize = 500;
    let last = null;
    const classAcc = {};
    let studentCount = 0;

    console.log('📖 Reading students from users collection...');
    
    while (true) {
      let q = db.collection('users').where('role', '==', 'student').limit(batchSize);
      if (last) q = q.startAfter(last);
      
      const snap = await q.get();
      if (snap.empty) break;
      
      console.log(`   Processing batch of ${snap.size} students...`);
      
      for (const d of snap.docs) {
        const u = d.data() || {};
        const uid = d.id;
        
        const rawSchool = u.tenant?.schoolId || u.school || null;
        const rawGrade = u.grade || u.class || null;
        
        if (!rawSchool || !rawGrade) {
          console.log(`   ⚠️  Skipping student ${uid} - missing school or class`);
          continue;
        }
        
        const normSchool = normalizeSchoolClass(rawSchool) || String(rawSchool);
        const normGrade = normalizeSchoolClass(rawGrade) || String(rawGrade).toLowerCase().replace(/\s+/g, '_');
        const classId = `${normSchool}_${normGrade}`;
        const xp = u.totalXP || u.xp || 0;
        
        // Compute quiz-based metrics for this student
        let studentAvgPercent = 0;
        let studentScoreSum = 0;
        let studentScoreCount = 0;
        let studentTotalQuestions = 0;
        const studentSubjects = new Set();
        
        try {
          const qs = await db.collection('quizzes').where('userId', '==', uid).get();
          for (const qd of qs.docs) {
            const qdData = qd.data() || {};
            
            if (qdData.percent != null) {
              const p = typeof qdData.percent === 'number' ? qdData.percent : parseFloat(String(qdData.percent)) || 0;
              studentScoreSum += p;
              studentScoreCount += 1;
            } else if (qdData.score != null && qdData.total != null) {
              const score = Number(qdData.score) || 0;
              const total = Number(qdData.total) || 0;
              if (total > 0) {
                const pct = (score / total) * 100;
                studentScoreSum += pct;
                studentScoreCount += 1;
              }
            }
            
            const subj = (qdData.subject || qdData.collectionName || '').toString();
            if (subj) studentSubjects.add(subj);
            studentTotalQuestions += Number(qdData.totalQuestions || qdData.total || 0) || 0;
          }
          
          if (studentScoreCount > 0) studentAvgPercent = studentScoreSum / studentScoreCount;
        } catch (e) {
          console.warn(`   ⚠️  Failed to compute quizzes for user ${uid}:`, e.message);
        }
        
        // Accumulate class-level aggregates
        if (!classAcc[classId]) {
          classAcc[classId] = {
            schoolId: String(rawSchool),
            grade: String(rawGrade),
            normalizedSchool: normSchool,
            normalizedClass: normGrade,
            totalXP: 0,
            totalStudents: 0,
            totalAttempts: 0,
            totalScoreSum: 0,
            totalScoreCount: 0,
            totalQuestions: 0,
            totalSubjects: 0
          };
        }
        
        classAcc[classId].totalXP += xp;
        classAcc[classId].totalStudents += 1;
        classAcc[classId].totalScoreSum += studentScoreSum;
        classAcc[classId].totalScoreCount += studentScoreCount;
        classAcc[classId].totalQuestions += studentTotalQuestions;
        classAcc[classId].totalSubjects += studentSubjects.size;
        
        // Write per-student summary doc
        await db.collection('studentSummaries').doc(uid).set({
          uid,
          totalXP: xp,
          questionsSolved: u.questionsSolved || u.questionsSolvedCount || 0,
          normalizedSchool: normSchool,
          normalizedClass: normGrade,
          teacherId: u.teacherId || null,
          firstName: u.profile?.firstName || u.firstName || null,
          lastName: u.profile?.lastName || u.lastName || null,
          email: u.email || u.profile?.email || null,
          avgPercent: studentAvgPercent,
          totalScoreSum: studentScoreSum,
          totalScoreCount: studentScoreCount,
          subjectsCount: studentSubjects.size,
          totalQuestions: studentTotalQuestions,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        studentCount++;
      }
      
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < batchSize) break;
    }
    
    console.log(`\n✅ Processed ${studentCount} students`);
    console.log(`📚 Writing ${Object.keys(classAcc).length} class aggregates...\n`);
    
    // Commit class aggregates
    const writes = [];
    for (const cid of Object.keys(classAcc)) {
      const c = classAcc[cid];
      writes.push(
        db.collection('classAggregates').doc(cid).set({
          schoolId: c.schoolId,
          grade: c.grade,
          normalizedSchool: c.normalizedSchool,
          normalizedClass: c.normalizedClass,
          totalXP: c.totalXP,
          totalStudents: c.totalStudents,
          totalScoreSum: c.totalScoreSum || 0,
          totalScoreCount: c.totalScoreCount || 0,
          totalQuestions: c.totalQuestions || 0,
          totalSubjects: c.totalSubjects || 0,
          avgScorePercent: (c.totalScoreCount && c.totalScoreCount > 0) 
            ? ((c.totalScoreSum || 0) / (c.totalScoreCount || 1)) 
            : 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true })
      );
    }
    
    await Promise.all(writes);
    
    console.log('🎉 Backfill completed successfully!');
    console.log(`\n📊 Summary:`);
    console.log(`   - ${studentCount} students processed`);
    console.log(`   - ${Object.keys(classAcc).length} classes updated`);
    console.log(`   - studentSummaries collection populated`);
    console.log(`   - classAggregates collection populated`);
    console.log(`\n✓ Teachers were EXCLUDED from aggregates`);
    console.log(`✓ Teacher dashboard should now show student data`);
    
    process.exit(0);
  } catch (e) {
    console.error('❌ ERROR during backfill:', e);
    process.exit(1);
  }
}

runBackfill();
