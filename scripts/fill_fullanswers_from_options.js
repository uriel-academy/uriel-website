const admin = require('firebase-admin');
const serviceAccount = require('../uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

function looksLikeLetterOnly(s) {
  if (!s) return true;
  const t = String(s).trim();
  return /^[A-E]$/i.test(t);
}

function optionLetterIndex(letter) {
  const up = (letter||'').toUpperCase();
  return up.charCodeAt(0) - 'A'.charCodeAt(0);
}

function normalizeOptionText(opt) {
  if (!opt) return null;
  const s = String(opt).trim();
  // If option already starts with 'A.' or 'A. ' or 'A) ' etc, return as-is
  if (/^[A-E][\.)]/i.test(s) || /^[A-E]\.\s/.test(s) || /^[A-E]\)\s/.test(s)) return s;
  // If starts with single letter and space 'A something', keep
  if (/^[A-E]\s+/i.test(s)) return s;
  return s;
}

async function main() {
  const snapshot = await db.collection('questions').where('subject','==','ict').get();
  let updated = 0, skipped = 0, failed = 0;
  const unable = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const id = doc.id;
    const correct = data.correctAnswer ? String(data.correctAnswer).trim().toUpperCase() : null;
    const full = data.fullAnswer ? String(data.fullAnswer).trim() : null;
    const options = Array.isArray(data.options) ? data.options : (data.options || []);

    if (!looksLikeLetterOnly(full)) {
      skipped++;
      continue; // already has full text
    }

    if (!correct) {
      failed++;
      unable.push({ id, reason: 'no correctAnswer' });
      continue;
    }

    // Try to find matching option by letter prefix
    let matched = null;
    for (const opt of options) {
      if (!opt) continue;
      const s = String(opt).trim();
      // matches like 'B. monitor' or 'B monitor' or 'B) monitor'
      const m = s.match(/^([A-E])[\.\)\s]\s*(.*)/i);
      if (m) {
        const letter = m[1].toUpperCase();
        if (letter === correct) {
          matched = s; break;
        }
      }
    }

    // If not found by prefix, try index mapping A->0
    if (!matched && options.length > 0) {
      const idx = optionLetterIndex(correct);
      if (idx >= 0 && idx < options.length) {
        const candidate = normalizeOptionText(options[idx]);
        // ensure candidate is not empty
        if (candidate && candidate.length > 0) matched = candidate;
      }
    }

    // As last resort, check options that contain the letter at start of string without punctuation
    if (!matched) {
      for (const opt of options) {
        const s = String(opt).trim();
        if (/^[A-E]\b/i.test(s)) {
          const letter = s.charAt(0).toUpperCase();
          if (letter === correct) { matched = s; break; }
        }
      }
    }

    if (!matched) {
      failed++;
      unable.push({ id, reason: 'no matching option', options, correct, full });
      continue;
    }

    // Ensure fullAnswer includes the letter prefix; if matched lacks letter prefix, add it
    let toWrite = matched;
    if (!/^[A-E][\.)\s]/i.test(matched)) {
      toWrite = `${correct}. ${matched}`;
    }

    try {
      await db.collection('questions').doc(id).update({ fullAnswer: toWrite, updatedAt: admin.firestore.FieldValue.serverTimestamp(), metadata: Object.assign({}, data.metadata || {}, { answerKeyAutoFilled: true }) });
      updated++;
      console.log('Filled', id, '->', toWrite);
    } catch (e) {
      failed++;
      unable.push({ id, reason: 'update failed', error: e.message || e });
    }
  }

  console.log('Done. updated=', updated, 'skipped=', skipped, 'failed=', failed);
  if (unable.length) console.log('Unable to fill examples:', unable.slice(0,10));
  await admin.app().delete();
}

main().catch(e => { console.error('Fatal', e); process.exit(1); });
