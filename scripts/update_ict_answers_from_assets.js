// Update ICT questions in Firestore with answer keys from assets
// Preference order for answers:
// 1) combined filled folder: assets/bece_ict/bece_ict_questions_2012_2022_filled/* (files that map year->answers or flat mappings)
// 2) per-year answers: assets/bece_ict/bece_ict_<year>_answers.json

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}
const db = admin.firestore();

function normalizeLetter(a) {
  if (!a && a !== 0) return null;
  if (typeof a === 'string') {
    const s = a.trim();
    // If like 'B. Text' or 'B' or 'B. Text' -> capture first letter A-E
    const m = s.match(/^([A-E])\b|^([A-E])\./i);
    if (m) return (m[1] || m[2]).toUpperCase();
    // if just single char
    if (/^[A-E]$/i.test(s)) return s.toUpperCase();
    return s.charAt(0).toUpperCase();
  }
  if (typeof a === 'object' && a.answer) return normalizeLetter(a.answer);
  return String(a).trim().charAt(0).toUpperCase();
}

const assetsRoot = path.join(__dirname, '..', 'assets', 'bece_ict');
const combinedDir = path.join(assetsRoot, 'bece_ict_questions_2012_2022_filled');
const years = [2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022];

async function loadCombined() {
  const result = {};
  if (!fs.existsSync(combinedDir)) return result;
  const files = fs.readdirSync(combinedDir).filter(f => f.endsWith('.json'));
  for (const f of files) {
    try {
      const jp = path.join(combinedDir, f);
      const json = JSON.parse(fs.readFileSync(jp, 'utf8'));
      // If shape is { '2012': { q1: 'B', ... } }
      for (const k of Object.keys(json)) {
        if (/^\d{4}$/.test(k)) {
          result[k] = Object.assign(result[k] || {}, json[k]);
        }
      }
      // Otherwise if file name contains year, assign
      const yearMatch = f.match(/(19|20)\d{2}/);
      if (yearMatch) {
        const y = yearMatch[0];
        // if json has multiple_choice -> map
        if (json.multiple_choice) {
          result[y] = Object.assign(result[y] || {}, json.multiple_choice);
        } else {
          // flat mapping like q1: 'B'
          result[y] = Object.assign(result[y] || {}, json);
        }
      }
      // If json itself is flat mapping '2012_q1' keys
      const flatKeys = Object.keys(json).filter(k => /\d{4}[_-]?q?\d+/i.test(k));
      for (const k of flatKeys) {
        const m = k.match(/(\d{4})[_-]?q?(\d+)/i);
        if (m) {
          const y = m[1];
          const qkey = 'q' + m[2];
          result[y] = result[y] || {};
          result[y][qkey] = json[k];
        }
      }
    } catch (e) {
      console.warn('Failed to parse combined file', f, e.message || e);
    }
  }
  return result;
}

async function loadPerYearAnswers() {
  const result = {};
  for (const y of years) {
    const p1 = path.join(assetsRoot, `bece_ict_${y}_answers.json`);
    const p2 = path.join(assetsRoot, `bece_ict_${y}_answers_fulltext.json`);
    const p3 = path.join(assetsRoot, `bece_ict_${y}_answers_fulltext.json`); // fallback duplicate name
    const p = fs.existsSync(p1) ? p1 : (fs.existsSync(p2) ? p2 : (fs.existsSync(p3) ? p3 : null));
    if (!p) continue;
    try {
      const json = JSON.parse(fs.readFileSync(p, 'utf8'));
      if (json.multiple_choice) result[String(y)] = json.multiple_choice;
      else result[String(y)] = json;
    } catch (e) {
      console.warn('Failed to parse per-year answers for', y, e.message || e);
    }
  }
  return result;
}

(async function main() {
  console.log('Loading combined answers...');
  const combined = await loadCombined();
  console.log('Loading per-year answers...');
  const perYear = await loadPerYearAnswers();

  // Merge: perYear takes precedence if combined missing
  const answersByYear = {};
  for (const y of years) {
    const ys = String(y);
    answersByYear[ys] = Object.assign({}, combined[ys] || {}, perYear[ys] || {});
  }

  let updated = 0, skipped = 0, missing = 0;
  for (const y of years) {
    const ys = String(y);
    const map = answersByYear[ys] || {};
    const keys = Object.keys(map);
    if (keys.length === 0) {
      console.log(`No answers found for ${ys}`);
      continue;
    }
    for (const k of keys) {
      // map key should be like 'q1' or '1'
      let qn = null;
      const m = k.match(/(\d+)$/);
      if (m) qn = parseInt(m[1], 10);
      else continue;
      const docId = `ict_${ys}_q${qn}`;
      const raw = map[k];
      const normalized = normalizeLetter(raw);
      const full = (typeof raw === 'string') ? raw.trim() : JSON.stringify(raw);
      try {
        const docRef = db.collection('questions').doc(docId);
        const snap = await docRef.get();
        if (!snap.exists) {
          missing++;
          console.warn('Doc missing:', docId);
          continue;
        }
        const data = snap.data() || {};
        const oldCorrect = data.correctAnswer ? String(data.correctAnswer).trim() : null;
        const oldFull = data.fullAnswer ? String(data.fullAnswer).trim() : null;
        if (oldCorrect === normalized && oldFull === full) {
          skipped++;
          continue;
        }
        await docRef.update({
          correctAnswer: normalized,
          fullAnswer: full,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          metadata: Object.assign({}, data.metadata || {}, { answerKeyUpdated: true })
        });
        updated++;
        console.log('Updated', docId, '->', normalized);
      } catch (e) {
        console.error('Error updating', docId, e.message || e);
      }
    }
  }

  console.log('Summary: updated=', updated, 'skipped=', skipped, 'missing=', missing);
  await admin.app().delete();
})();
