#!/usr/bin/env node
// Normalize Ghanaian language question documents imported by import_ghanaian_local.js
// Usage: node normalize_ghanaian_questions.js --serviceAccount="./serviceAccount.json"

const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  args.forEach(arg => {
    if (arg.startsWith('--')) {
      const [k, v] = arg.split('=');
      out[k.replace(/^--/, '')] = v === undefined ? true : v;
    }
  });
  return out;
}

(async function main(){
  const args = parseArgs();
  const serviceAccountPath = args.serviceAccount || './uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

  let admin;
  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error('\nError: missing dependency `firebase-admin`. Install it in the repo root:');
    console.error('  npm install firebase-admin');
    process.exit(1);
  }

  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found at ${serviceAccountPath}. Provide with --serviceAccount=PATH`);
    process.exit(1);
  }

  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  console.log('Querying for imported Ghanaian language docs (metadata.source == local_import_script)...');
  const snapshot = await db.collection('questions').where('metadata.source', '==', 'local_import_script').get();
  console.log(`Found ${snapshot.size} documents to normalize.`);

  if (snapshot.empty) {
    console.log('No docs to process. Exiting.');
    process.exit(0);
  }

  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Build normalized fields
    const newDoc = {};

    // id
    newDoc.id = doc.id;

    // questionText
    const qText = data.questionText || data.question || data.prompt || data['Question'] || '';
    newDoc.questionText = String(qText || '').trim();

    // options: normalize to array of strings like 'A. Option text'
    let rawOptions = data.options || data.optionsMap || data.choices || data.choicesList || [];
    // If options were objects like [{key:'A', text:'...'}, ...]
    if (Array.isArray(rawOptions) && rawOptions.length > 0 && typeof rawOptions[0] === 'object') {
      rawOptions = rawOptions.map(o => {
        if (o.text) return String(o.text);
        if (o.option) return String(o.option);
        return JSON.stringify(o);
      });
    }

    // If options is an object mapping A->text
    if (!Array.isArray(rawOptions) && rawOptions && typeof rawOptions === 'object') {
      rawOptions = Object.entries(rawOptions).map(([k, v]) => String(v));
    }

    rawOptions = Array.isArray(rawOptions) ? rawOptions.map(o => o == null ? '' : String(o)) : [];

    // Trim and ensure not empty
    rawOptions = rawOptions.map(o => o.trim()).filter(o => o.length > 0);

    // If options exist but don't start with letter+dot, prefix them
    const normalizedOptions = rawOptions.map((opt, idx) => {
      const trimmed = opt.trim();
      // If already starts with 'A.' or 'A)'
      if (/^[A-Z]\s*[\.|\)]/i.test(trimmed) || /^[A-Z]\s*\./i.test(trimmed)) {
        return trimmed;
      }
      const prefix = letters[idx] ? `${letters[idx]}. ` : '';
      return `${prefix}${trimmed}`.trim();
    });

    newDoc.options = normalizedOptions.length > 0 ? normalizedOptions : null;

    // correctAnswer: normalize to letter (A, B, ...), or if we can't determine, keep as-is
    let corr = data.correctAnswer || data.answer || data.correct || null;
    if (corr != null) corr = String(corr).trim();

    let normalizedCorrect = '';
    if (newDoc.options != null && newDoc.options.length > 0) {
      if (!corr) {
        // try to use data.metadata.correctIndex
        if (data.metadata && typeof data.metadata.correctIndex === 'number') {
          normalizedCorrect = letters[data.metadata.correctIndex] || letters[0];
        } else {
          // Leave empty — will default to first option
          normalizedCorrect = '';
        }
      } else {
        // If corr is numeric string
        const num = parseInt(corr, 10);
        if (!isNaN(num) && num >= 0 && num < newDoc.options.length) {
          normalizedCorrect = letters[num];
        } else if (/^[A-Za-z]$/.test(corr)) {
          normalizedCorrect = corr.toUpperCase();
        } else if (/^[A-Za-z]\./.test(corr)) {
          normalizedCorrect = corr[0].toUpperCase();
        } else {
          // Maybe corr is the full text — find matching option
          const matchIdx = newDoc.options.findIndex(opt => opt.toLowerCase().includes(corr.toLowerCase()));
          if (matchIdx >= 0) normalizedCorrect = letters[matchIdx];
          else normalizedCorrect = corr.length <= 2 ? corr.toUpperCase() : letters[0];
        }
      }
    } else {
      // No options — treat as short answer; set correctAnswer to string version
      normalizedCorrect = corr ? corr : '';
    }

    newDoc.correctAnswer = normalizedCorrect;

    // type
    newDoc.type = newDoc.options != null ? 'multipleChoice' : 'shortAnswer';

    // subject
    newDoc.subject = 'ghanaianLanguage';

    // examType — default to 'practice'
    newDoc.examType = data.examType || 'practice';

    // year — ensure string
    newDoc.year = data.year ? String(data.year) : (data.sourceFile ? ( (data.sourceFile.match(/(19|20)\d{2}/) || [null])[0] || '' ) : '');

    // section
    newDoc.section = data.section || data.sectionName || '';

    // questionNumber
    newDoc.questionNumber = data.questionNumber ? Number(data.questionNumber) : (data.metadata && data.metadata.idx ? Number(data.metadata.idx) + 1 : 0);

    // explanation, imageUrl
    newDoc.explanation = data.explanation || '';
    newDoc.imageUrl = data.imageUrl || data.image || '';

    newDoc.marks = data.marks ? Number(data.marks) : 1;
    newDoc.difficulty = data.difficulty || 'medium';
    newDoc.topics = Array.isArray(data.topics) ? data.topics : [];

    // createdAt: use metadata.importedAt if available (Firestore Timestamp), else serverTimestamp
    if (data.metadata && data.metadata.importedAt) {
      newDoc.createdAt = data.metadata.importedAt;
    } else {
      newDoc.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    newDoc.createdBy = data.metadata && data.metadata.importedBy ? data.metadata.importedBy : 'ghanaian_import';
    newDoc.isActive = data.isActive == null ? true : data.isActive;

    // Merge back
    try {
      await db.collection('questions').doc(doc.id).set(newDoc, { merge: true });
      updated++;
    } catch (e) {
      console.error(`Failed to update ${doc.id}:`, e);
    }
  }

  console.log(`Normalization complete. Documents updated: ${updated}`);
  process.exit(0);
})();
