#!/usr/bin/env node
// Local admin import script for Ghanaian language questions
// Usage: node import_ghanaian_local.js --assetsDir="assets/ghanaian language" [--serviceAccount=./serviceAccount.json]

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
  const assetsDir = args.assetsDir || 'assets/ghanaian language';
  const serviceAccountPath = args.serviceAccount || './uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';

  // Try to require firebase-admin
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error('\nError: missing dependency `firebase-admin`. Install it in the repo root:');
    console.error('  npm install firebase-admin');
    process.exit(1);
  }

  // Check service account
  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`\nService account file not found at ${serviceAccountPath}. Provide with --serviceAccount=PATH`);
    process.exit(1);
  }

  const serviceAccount = require(path.resolve(serviceAccountPath));

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();

  const absAssetsDir = path.resolve(assetsDir);
  if (!fs.existsSync(absAssetsDir) || !fs.lstatSync(absAssetsDir).isDirectory()) {
    console.error(`\nAssets directory not found at ${absAssetsDir}`);
    process.exit(1);
  }

  const files = fs.readdirSync(absAssetsDir).filter(f => f.toLowerCase().endsWith('.json'));
  if (files.length === 0) {
    console.error(`\nNo .json files found in ${absAssetsDir}.`);
    process.exit(1);
  }

  console.log(`Found ${files.length} json file(s) in ${absAssetsDir}. Starting import...`);

  let totalImported = 0;
  for (const fileName of files) {
    const filePath = path.join(absAssetsDir, fileName);
    let raw;
    try {
      raw = fs.readFileSync(filePath, 'utf8');
    } catch (e) {
      console.error(`Failed reading ${filePath}: ${e}`);
      continue;
    }

    let json;
    try {
      json = JSON.parse(raw);
    } catch (e) {
      console.error(`Failed parsing JSON in ${fileName}: ${e}`);
      continue;
    }

    // Determine year from filename if present (e.g., ga_2023 or 2023)
    const yearMatch = fileName.match(/(19|20)\d{2}/);
    const year = yearMatch ? parseInt(yearMatch[0], 10) : null;

    // Normalize different JSON shapes
    const questions = [];
    if (Array.isArray(json)) {
      // root is array
      json.forEach((q, idx) => questions.push({ q, meta: { idx } }));
    } else if (json.questions && Array.isArray(json.questions)) {
      json.questions.forEach((q, idx) => questions.push({ q, meta: { idx } }));
    } else if (json.items && Array.isArray(json.items)) {
      json.items.forEach((q, idx) => questions.push({ q, meta: { idx } }));
    } else if (json.multiple_choice && typeof json.multiple_choice === 'object') {
      // mapping keyed by "Q1" etc
      Object.entries(json.multiple_choice).forEach(([key, q], idx) => questions.push({ q, meta: { key, idx } }));
    } else {
      // try to treat top-level object as single question or map
      if (json.question || json.questionText || json.prompt) {
        questions.push({ q: json, meta: { single: true } });
      } else {
        // fallback: iterate object values that look like questions
        Object.values(json).forEach((val, idx) => {
          if (val && (val.question || val.prompt || val.options)) {
            questions.push({ q: val, meta: { idx } });
          }
        });
      }
    }

    if (questions.length === 0) {
      console.warn(`No questions found in ${fileName}, skipping.`);
      continue;
    }

    console.log(`Importing ${questions.length} question(s) from ${fileName} ...`);

    for (let i = 0; i < questions.length; i++) {
      const item = questions[i].q;
      // Heuristics for fields
      const questionText = item.questionText || item.question || item.prompt || item.q || item.text || item['Question'] || null;

      // Options may be either array or object mapping
      let options = [];
      if (Array.isArray(item.options)) {
        options = item.options;
      } else if (item.options && typeof item.options === 'object') {
        // map to array [A, B, C, ...] maintaining keys order if possible
        options = Object.entries(item.options).map(([k, v]) => ({ key: k, text: v }));
      } else if (item.choices && Array.isArray(item.choices)) {
        options = item.choices;
      }

      let correctAnswer = item.correct || item.answer || item.correctAnswer || item['Answer'] || null;

      // If correctAnswer is index or letter, try to normalize
      if (typeof correctAnswer === 'number' && options.length > correctAnswer) {
        // leave as index
      }

      const doc = {
        subject: 'ghanaianLanguage',
        sourceFile: fileName,
        year: year,
        questionText: questionText || '',
        options: options,
        correctAnswer: correctAnswer,
        metadata: {
          importedAt: admin.firestore.FieldValue.serverTimestamp(),
          source: 'local_import_script',
        }
      };

      try {
        await db.collection('questions').add(doc);
        totalImported++;
      } catch (e) {
        console.error(`Failed to write question ${i} from ${fileName}: ${e}`);
      }
    }
  }

  console.log(`\nImport complete. Total documents imported: ${totalImported}`);

  // Write summary doc
  try {
    await db.collection('app_metadata').doc('ghanaian_language_import').set({
      lastImportedAt: admin.firestore.FieldValue.serverTimestamp(),
      count: totalImported,
      assetsDir: assetsDir,
    });
    console.log('Wrote summary doc to app_metadata/ghanaian_language_import');
  } catch (e) {
    console.error('Failed to write summary doc:', e);
  }

  process.exit(0);
})();
