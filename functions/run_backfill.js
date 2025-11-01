const admin = require('firebase-admin');
const path = require('path');

// Path to service account JSON in repo root
const svcPath = path.resolve(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
const serviceAccount = require(svcPath);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

function normalizeSchoolClass(raw) {
  if (raw === undefined || raw === null) return null;
  let s = String(raw).toLowerCase();
  s = s.replace(/\b(school|college|high school|senior high school|senior|basic|primary|jhs|shs|the)\b/g, ' ');
  s = s.replace(/[^a-z0-9\s]/g, ' ');
  s = s.replace(/\s+/g, ' ').trim();
  if (!s) return null;
  return s.replace(/\s+/g, '_');
}

async function run() {
  console.log('Starting backfill...');
  const batchSize = 500;
  let last = null;
  const classAcc = {};
  while (true) {
    let q = db.collection('users').where('role', '==', 'student').limit(batchSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    for (const d of snap.docs) {
      const u = d.data() || {};
      const uid = d.id;
      const rawSchool = u.tenant && u.tenant.schoolId ? u.tenant.schoolId : (u.school || null);
      const rawGrade = u.grade || u.class || null;
      if (!rawSchool || !rawGrade) continue;
      const normSchool = normalizeSchoolClass(rawSchool) || String(rawSchool);
      const normGrade = normalizeSchoolClass(rawGrade) || String(rawGrade).toLowerCase().replace(/\s+/g, '_');
      const cid = `${normSchool}_${normGrade}`;
      const xp = (u.totalXP || u.xp) || 0;
      // compute quiz metrics for student
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
          const subj = (qdData.subject || qdData.collectionName || '') + '';
          if (subj) studentSubjects.add(subj);
          studentTotalQuestions += Number(qdData.totalQuestions || qdData.total || 0) || 0;
        }
      } catch (e) { console.warn('run_backfill: failed to query quizzes for', uid, e); }

      if (!classAcc[cid]) classAcc[cid] = { schoolId: String(rawSchool), grade: String(rawGrade), normalizedSchool: normSchool, normalizedClass: normGrade, totalXP: 0, totalStudents: 0, totalAttempts: 0, totalScoreSum: 0, totalScoreCount: 0, totalQuestions: 0, totalSubjects: 0 };
      classAcc[cid].totalXP += xp;
      classAcc[cid].totalStudents += 1;
      classAcc[cid].totalScoreSum += studentScoreSum;
      classAcc[cid].totalScoreCount += studentScoreCount;
      classAcc[cid].totalQuestions += studentTotalQuestions;
      classAcc[cid].totalSubjects += studentSubjects.size;

      await db.collection('studentSummaries').doc(uid).set({
        uid,
        totalXP: xp,
        questionsSolved: (u.questionsSolved || u.questionsSolvedCount) || 0,
        normalizedSchool: normSchool,
        normalizedClass: normGrade,
        teacherId: u.teacherId || null,
        firstName: (u.profile && u.profile.firstName) || u.firstName || null,
        lastName: (u.profile && u.profile.lastName) || u.lastName || null,
        email: u.email || (u.profile && u.profile.email) || null,
        avgPercent: studentScoreCount > 0 ? (studentScoreSum / studentScoreCount) : 0,
        totalScoreSum: studentScoreSum,
        totalScoreCount: studentScoreCount,
        subjectsCount: studentSubjects.size,
        totalQuestions: studentTotalQuestions,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize) break;
  }

  // Write class aggregates
  const writes = [];
  for (const cid of Object.keys(classAcc)) {
    const c = classAcc[cid];
    writes.push(db.collection('classAggregates').doc(cid).set({
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
      avgScorePercent: (c.totalScoreCount && c.totalScoreCount > 0) ? ((c.totalScoreSum || 0) / (c.totalScoreCount || 1)) : 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true }));
  }

  await Promise.all(writes);
  console.log('Backfill complete. classesUpdated=', Object.keys(classAcc).length);
  process.exit(0);
}

run().catch(err => { console.error('Backfill failed', err); process.exit(2); });
