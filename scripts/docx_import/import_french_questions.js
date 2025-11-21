#!/usr/bin/env node
/**
 * import_french_questions.js
 *
 * French-specific import script that handles:
 * - Passages stored in separate 'passages' collection
 * - Questions linked via passageId
 * - Special handling for top-down options format (post-2010)
 * - Skip answers for 1990-1999 (to be provided later)
 */

const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');
const { Buffer } = require('buffer');

function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach((a) => {
    if (a.startsWith('--')) {
      const eqIndex = a.indexOf('=');
      if (eqIndex > 0) {
        const k = a.substring(2, eqIndex);
        const v = a.substring(eqIndex + 1);
        args[k] = v;
      } else {
        args[a.substring(2)] = true;
      }
    }
  });
  return args;
}

function readDirDocx(folder) {
  const files = fs.readdirSync(folder || '.');
  return files.filter(f => f.toLowerCase().endsWith('.docx')).map(f => path.join(folder, f));
}

async function docxToText(filePath) {
  const result = await mammoth.extractRawText({ path: filePath });
  return result.value;
}

function splitQuestionsFromText(text, year) {
  // Normalize newlines
  text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  text = text.replace(/\n{3,}/g, '\n\n');

  let passage = null;
  let questions = [];

  // For French, passages are typically at the beginning
  // Look for passage markers or long text blocks before questions
  const firstQuestionMatch = text.search(/(^|\n)\s*\d{1,2}[\).\s]/m);
  if (firstQuestionMatch > 0) {
    const lead = text.slice(0, firstQuestionMatch).trim();
    // Consider it a passage if it contains "TEXTE" or is substantial (>100 chars)
    if (lead.includes('TEXTE') || lead.length > 100) {
      passage = lead;
      text = text.slice(firstQuestionMatch);
    }
  }

  // Special handling for post-2010 files with top-down options
  const isPost2010 = year && parseInt(year) > 2010;
  const isTopDownFormat = isPost2010 && text.includes('A.') && text.includes('B.');

  if (isTopDownFormat) {
    // Handle top-down format where options appear vertically after each question
    questions = parseTopDownFormat(text);
  } else {
    // Standard parsing
    questions = parseStandardFormat(text);
  }

  return { passage, questions };
}

function parseTopDownFormat(text) {
  const questions = [];
  // Find all question blocks using regex
  const questionRegex = /(?:^|\n)\s*(\d{1,2})[\).\s]*([^\n]*?)(?=(?:\n\s*\d{1,2}[\).\s]|$))/g;
  let match;

  while ((match = questionRegex.exec(text)) !== null) {
    const num = parseInt(match[1], 10);
    let body = match[2].trim();

    // Extract question text and options from the body
    let questionText = '';
    let options = [];

    // Simple approach: split by option markers
    const parts = body.split(/([A-D])\.\s*/).filter(p => p.trim().length > 0);

    if (parts.length >= 3) { // At least question + 2 options
      questionText = parts[0].trim();

      // Group letter + text pairs
      options = [];
      for (let i = 1; i < parts.length; i += 2) {
        if (i + 1 < parts.length) {
          const letter = parts[i];
          const text = parts[i + 1].trim();
          if (/^[A-D]$/.test(letter)) {
            options.push(text);
          }
        }
      }
    }

    // Clean up question text
    questionText = questionText.replace(/\s+/g, ' ').trim();

    if (questionText && options.length >= 2) {
      questions.push({
        questionNumber: num,
        questionText,
        options,
        _removedLeadingChoice: false
      });
    }
  }

  return questions;
}

function parseStandardFormat(text) {
  // Similar to the original parsing logic but simplified for French
  const questions = [];
  const qRegex = /(?:^|\n)\s*(\d{1,2})[\).\s]*([\s\S]*?)(?=(?:\n\s*\d{1,2}[\).\s]|$))/g;

  let m;
  while ((m = qRegex.exec(text)) !== null) {
    const num = parseInt(m[1], 10);
    let body = m[2].trim();

    // Extract options - look for A., B., C., D. patterns
    const lines = body.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    let options = [];
    let questionLines = [];

    lines.forEach(line => {
      const optMatch = line.match(/^([A-D])(?:\.|\)|\s|[-–—:])\s*(.+)$/i);
      if (optMatch) {
        options.push(optMatch[2].trim());
      } else {
        questionLines.push(line);
      }
    });

    // If no options found, try inline extraction
    if (options.length === 0) {
      const extracted = extractInlineOptions(body);
      if (extracted) {
        options = extracted.options;
        questionLines = [extracted.question];
      }
    }

    let questionText = questionLines.join(' ');

    questions.push({
      questionNumber: num,
      questionText,
      options,
      _removedLeadingChoice: false
    });
  }

  return questions;
}

function extractInlineOptions(s) {
  const normalized = s.replace(/([A-Da-d])(?:[\.\)\-–—:])(?=[A-Za-z0-9])/g, '$1. ');
  const parts = normalized.split(/(?=[A-Da-d][\.\)])/g).map(p => p.trim()).filter(Boolean);

  if (parts.length < 2) return null;

  const qpart = parts.shift();
  const opts = parts.map(p => p.replace(/^[A-Da-d][\.\)]\s*/i, '').trim()).filter(Boolean);

  if (opts.length === 0) return null;
  return { question: qpart, options: opts };
}

function tryParseAnswersFromText(text, year) {
  // Skip answers for 1990-1999 as user will provide them later
  if (year && parseInt(year) >= 1990 && parseInt(year) <= 1999) {
    return {};
  }

  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  const answers = {};

  lines.forEach(l => {
    const m = l.match(/^(\d{1,2})[\)\.\-\s]*([A-D])[\.\)]?/i);
    if (m) answers[parseInt(m[1], 10)] = m[2].toUpperCase();
  });

  return answers;
}

async function importToFirestore(results, serviceAccountPath) {
  const admin = require('firebase-admin');
  const sa = require(path.resolve(serviceAccountPath));

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      storageBucket: sa.project_id + '.appspot.com'
    });
  }

  const db = admin.firestore();

  // First, import passages
  const passageBatch = db.batch();
  let passageCount = 0;

  for (const result of results) {
    if (result.passage && result.year) {
      const passageId = `french_${result.year}_passage`.replace(/\s+/g, '_').toLowerCase();
      const passageRef = db.collection('french_passages').doc(passageId);

      const passageData = {
        id: passageId,
        title: `French Comprehension Passage ${result.year}`,
        content: result.passage,
        subject: 'french',
        examType: 'bece',
        year: result.year,
        section: 'COMPREHENSION',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'french_import',
        isActive: true
      };

      passageBatch.set(passageRef, passageData);
      passageCount++;

      // Add passageId to all questions in this result
      result.docs.forEach(doc => {
        doc.passageId = passageId;
      });
    }
  }

  if (passageCount > 0) {
    await passageBatch.commit();
    console.log(`Imported ${passageCount} French passages to french_passages collection`);
  }

  // Then import questions
  const questionBatch = db.batch();
  let questionCount = 0;

  for (const result of results) {
    for (const doc of result.docs) {
      // Skip documents with missing required fields
      if (!doc.year || !doc.questionNumber || !doc.questionText) {
        console.warn(`Skipping question with missing data: year=${doc.year}, qNum=${doc.questionNumber}`);
        continue;
      }

      const id = `french_${doc.year}_${doc.questionNumber}`.replace(/\s+/g, '_').toLowerCase();
      const docRef = db.collection('french_questions').doc(id);

      const payload = {
        ...doc,
        id,
        subject: 'french',
        type: 'multipleChoice',
        marks: 1,
        difficulty: 'medium',
        topics: [],
        explanation: null,
        isActive: true,
        createdBy: 'french_import',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      questionBatch.set(docRef, payload);
      questionCount++;
    }
  }

  await questionBatch.commit();
  console.log(`Imported ${questionCount} French questions to french_questions collection`);
}

async function processFile(filePath) {
  const raw = await docxToText(filePath);
  const base = path.basename(filePath, '.docx');
  const year = (base.match(/(19|20)\d{2}/) || [''])[0];

  const { passage, questions } = splitQuestionsFromText(raw, year);

  return {
    passage,
    questions,
    year,
    fileName: base
  };
}

async function main() {
  const args = parseArgs();
  const folder = args.folder || path.join(__dirname, '..', '..', 'assets', 'bece french');
  const outDir = args.out || path.join(__dirname, '..', 'output_french');
  const doImport = !!args.import;
  const serviceAccountPath = args.serviceAccountPath;

  if (!fs.existsSync(folder)) {
    console.error('Folder not found:', folder);
    process.exit(1);
  }

  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const docxFiles = readDirDocx(folder);
  const results = [];

  for (const f of docxFiles) {
    console.log('Processing', path.basename(f));
    try {
      const { passage, questions, year, fileName } = await processFile(f);

      // Load answers if available (skip for 1990-1999)
      let answersMap = {};
      if (year && parseInt(year) > 1999) {
        const answersFile = docxFiles.find(x =>
          path.basename(x).toLowerCase().includes('answers') ||
          path.basename(x).toLowerCase().includes('key')
        );

        if (answersFile) {
          try {
            const answersRaw = await docxToText(answersFile);
            answersMap = tryParseAnswersFromText(answersRaw, year);
          } catch (e) {
            console.warn('Failed to load answers for', year);
          }
        }
      }

      // Merge answers
      const mergedQuestions = questions.map(q => ({
        ...q,
        correctAnswer: answersMap[q.questionNumber] || null
      }));

      // Build docs for import
      const outDocs = mergedQuestions.map(q => ({
        subject: 'french',
        year,
        examType: 'bece',
        section: passage ? 'COMPREHENSION' : 'A',
        questionNumber: q.questionNumber,
        questionText: q.questionText,
        options: q.options,
        displayOptions: q.options.map((o, i) => `${String.fromCharCode(65 + i)}. ${o}`),
        correctAnswer: q.correctAnswer,
        passage: passage || null,
        metadata: {
          sourceFile: path.basename(f),
          importedAt: new Date().toISOString()
        }
      }));

      // Save to JSON
      const outPath = path.join(outDir, `${fileName}.json`);
      fs.writeFileSync(outPath, JSON.stringify(outDocs, null, 2), 'utf8');
      console.log(`Wrote ${outDocs.length} questions to ${outPath}`);

      results.push({ file: f, docs: outDocs, passage });

    } catch (err) {
      console.error('Error processing', f, err);
    }
  }

  // Import to Firestore if requested
  if (doImport && serviceAccountPath) {
    if (results.length > 0) {
      console.log(`Importing French questions and passages to Firestore...`);
      await importToFirestore(results, serviceAccountPath);
    }
  } else if (doImport) {
    console.error('--import requires --serviceAccountPath');
  }

  console.log('French import complete!');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});