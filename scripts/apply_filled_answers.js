// Apply filled ICT answer keys from assets to Firestore questions
// Usage: node scripts/apply_filled_answers.js

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

function normalizeAnswer(a) {
  if (!a && a !== 0) return null;
  if (typeof a === 'string') {
    const s = a.trim();
    // If format like 'B. Keyboard' or 'B' -> extract letter before '.' or first char if single letter
    const m = s.match(/^([A-Z]|[A-Z])\b\.?/i);
    if (m) return m[1].toUpperCase();
    // fallback: first non-space character
    return s.charAt(0).toUpperCase();
  }
  if (typeof a === 'object' && a.answer) {
    return normalizeAnswer(a.answer);
  }
  return String(a).trim().charAt(0).toUpperCase();
}

function mergeInto(map, year, key, value) {
  if (!map[year]) map[year] = {};
  map[year][key] = value;
}

async function main() {
  // Look for combined filled answers folder first
  const combinedDir = path.join(__dirname, '..', 'assets', 'bece_ict', 'bece_ict_questions_2012_2022_filled');
  let files = [];
  if (fs.existsSync(combinedDir)) {
    files = fs.readdirSync(combinedDir).filter(f => f.endsWith('.json')).map(f => path.join(combinedDir, f));
  }

  // Fallback: per-year answers files directly under assets/bece_ict
  const assetsRoot = path.join(__dirname, '..', 'assets', 'bece_ict');
  const years = [];
  for (let y = 2011; y <= 2022; y++) years.push(String(y));
  for (const y of years) {
    const perYear = path.join(assetsRoot, `bece_ict_${y}_answers.json`);
    if (fs.existsSync(perYear)) files.push(perYear);
  }

  if (files.length === 0) {
    console.error('No filled answer JSON files found in combined folder or per-year assets. Checked:', combinedDir, 'and', assetsRoot);
    process.exit(1);
  }

  const filled = {}; // { year: { q1: fullAnswer } }

  for (const filePath of files) {
    const file = path.basename(filePath);
    let json;
    try {
      json = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
      console.error('Failed to parse', filePath, e.message || e);
      continue;
    }

    // Heuristics: If top-level has numeric year keys, merge
  const topKeys = Object.keys(json);
    const hasYearKeys = topKeys.some(k => /^\d{4}$/.test(k));
    if (hasYearKeys) {
      for (const y of topKeys) {
        if (/^\d{4}$/.test(y)) {
          const val = json[y];
          if (typeof val === 'object') {
            // val might be { q1: 'B', q2: 'A', ... }
            for (const qk of Object.keys(val)) {
              mergeInto(filled, y, qk.toLowerCase(), val[qk]);
            }
          }
        }
      }
      continue;
    }

    // If file name contains a year, use it
    const yearMatch = file.match(/(19|20)\d{2}/);
    if (yearMatch) {
      const year = yearMatch[0];
      // If json is flat mapping q1..q40
      for (const k of Object.keys(json)) {
        mergeInto(filled, year, k.toLowerCase(), json[k]);
      }
      continue;
    }

    // If keys look like '2012_q1' or 'ict_2012_q1'
    const flatYearKeyRegex = /^(?:ict_)?(\d{4})[_-]?q?(\d{1,2})$/i;
    const otherKeys = Object.keys(json);
    let matchedAny = false;
    for (const k of otherKeys) {
      const m = k.match(flatYearKeyRegex);
      if (m) {
        const y = m[1];
        const qn = 'q' + m[2];
        mergeInto(filled, y, qn.toLowerCase(), json[k]);
        matchedAny = true;
      }
    }
    if (matchedAny) continue;

    // If none of the above, assume the file is a mapping for years nested in strings like '2012_q1'
    // As a fallback, if there's only q1..q40 keys, try to infer year from parent directory name '2012-2022' - but we don't have it.
    // Finally, try to detect keys like 'q1' and if file name contains a year range, apply to all years (not ideal).
    const qKeys = otherKeys.filter(k => /^q\d+/i.test(k));
    if (qKeys.length > 0 && yearMatch) {
      const y = yearMatch[0];
      for (const k of qKeys) mergeInto(filled, y, k.toLowerCase(), json[k]);
    } else {
      // Merge top-level keys into '2012' if filename suggests 2012-2022; otherwise skip
      if (/2012_2022|2012-2022|2012to2022/i.test(file)) {
        // Try to distribute keys by year if keys are like '2012_q1' etc. If not, put whole object under '2012'
        mergeInto(filled, '2012', 'combined', json);
      } else {
        console.warn('Could not infer year mapping for file:', file, ' — skipping');
      }
    }
  }

  // Now we have filled map; update Firestore docs accordingly
  let updated = 0;
  let skipped = 0;
  let missing = 0;

  for (const year of Object.keys(filled)) {
    const qmap = filled[year];
    for (const qk of Object.keys(qmap)) {
      // qk might be 'q1' or '1' or 'q01'
      const qnMatch = qk.match(/(\d+)$/);
      let qn = null;
      if (qnMatch) qn = parseInt(qnMatch[1], 10);
      else if (/^q(\d+)/i.test(qk)) qn = parseInt(qk.replace(/^q/i, ''), 10);
      else continue; // skip keys we can't parse

      const docId = `ict_${year}_q${qn}`;
      const fullAnswer = qmap[qk];
      const normalized = normalizeAnswer(fullAnswer);
      try {
        const docRef = db.collection('questions').doc(docId);
        const doc = await docRef.get();
        if (!doc.exists) {
          missing++;
          console.warn('Doc missing:', docId);
          continue;
        }
        const data = doc.data() || {};
        const oldCorrect = data.correctAnswer ? String(data.correctAnswer).trim() : null;
        const oldFull = data.fullAnswer ? String(data.fullAnswer).trim() : null;
        const newCorrect = normalized;
        const newFull = typeof fullAnswer === 'string' ? fullAnswer.trim() : JSON.stringify(fullAnswer);

        if (oldCorrect === newCorrect && oldFull === newFull) {
          skipped++;
          continue;
        }

        await docRef.update({
          correctAnswer: newCorrect,
          fullAnswer: newFull,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          metadata: Object.assign({}, data.metadata || {}, { answerKeyUpdated: true })
        });
        updated++;
        console.log('Updated', docId, '->', newCorrect);
      } catch (e) {
        console.error('Error updating', docId, e.message || e);
      }
    }
  }

  console.log('Summary: updated=', updated, 'skipped=', skipped, 'missing=', missing);
  await admin.app().delete();
}

main().catch(err => {
  console.error('Fatal', err);
  process.exit(1);
});
