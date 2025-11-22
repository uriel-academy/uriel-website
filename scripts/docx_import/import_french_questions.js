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
  const argv = process.argv.slice(2);

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.substring(2);
      const eqIndex = key.indexOf('=');
      if (eqIndex > 0) {
        // --key=value format
        const k = key.substring(0, eqIndex);
        const v = key.substring(eqIndex + 1);
        args[k] = v;
      } else {
        // --key value format
        const k = key;
        const v = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : true;
        args[k] = v;
        if (v !== true) i++; // Skip the next argument if it was consumed as a value
      }
    }
  }

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

  const passagesAndQuestions = [];

  // Split by PART markers (PART I, PART II, etc.)
  const partRegex = /PART\s+(?:I{1,3}|IV|II{1,2}|III)/gi;
  const parts = text.split(partRegex);

  if (parts.length > 1) {
    // Multiple parts found - process each part separately
    const partHeaders = text.match(partRegex) || [];

    for (let i = 1; i < parts.length; i++) {
      const partContent = parts[i].trim();
      const partHeader = partHeaders[i-1] || `PART ${i}`;

      console.log(`Processing ${partHeader}...`);

      const partResults = parsePartContent(partContent, year, partHeader);
      passagesAndQuestions.push(...partResults);
    }
  } else {
    // Single part or no clear parts - process as one
    const partResults = parsePartContent(text, year, 'PART I');
    passagesAndQuestions.push(...partResults);
  }

  return { passagesAndQuestions };
}

function parsePartContent(text, year, partHeader) {
  const results = [];

  // Special handling for 2025 Part 3 - questions 31-40 have a fill-in passage
  if (year === '2025' && partHeader.includes('PART III')) {
    return parsePart3_2025(text, year, partHeader);
  }

  // Split by TEXTE markers (TEXTE 1, TEXTE 2, etc.)
  const texteRegex = /TEXTE\s+\d+:/gi;
  const textes = text.split(texteRegex);

  if (textes.length > 1) {
    // Multiple textes found
    const texteHeaders = text.match(texteRegex) || [];

    for (let i = 1; i < textes.length; i++) {
      const texteContent = textes[i].trim();
      const texteHeader = texteHeaders[i-1] || `TEXTE ${i}`;

      console.log(`  Processing ${texteHeader}...`);

      const texteResults = parseTexteContent(texteContent, year, `${partHeader} - ${texteHeader}`);
      results.push(...texteResults);
    }
  } else {
    // No clear textes - treat as single passage for the part
    const texteResults = parseTexteContent(text, year, partHeader);
    results.push(...texteResults);
  }

  return results;
}

function parseTexteContent(text, year, context) {
  const results = [];

  // For 2024+ format, questions may be embedded in the text
  // Look for the first question anywhere in the text
  const firstQuestionMatch = text.search(/\d{1,2}[\).\s]/);
  let passage = null;
  let questionsText = text;

  if (firstQuestionMatch > 0) {
    // Extract everything from start up to first question as the passage
    const potentialPassage = text.slice(0, firstQuestionMatch).trim();

    // Consider it a passage if it's substantial (>20 chars) and contains meaningful content
    if (potentialPassage.length > 20 && !potentialPassage.toLowerCase().includes('answer')) {
      passage = potentialPassage;
      questionsText = text.slice(firstQuestionMatch);
    }
  }

  // Parse questions from the remaining text
  const questions = parseQuestionsFromText(questionsText, year);

  // Associate passage with questions (typically 4-5 questions per passage)
  if (passage && questions.length > 0) {
    // For 2024 format, each TEXTE should have exactly 5 questions
    const questionsPerPassage = 5;

    if (questions.length <= questionsPerPassage) {
      // All questions belong to this passage
      results.push({
        passage: passage,
        questions: questions,
        context: context,
        year: year
      });
    } else {
      // More questions than expected - split them
      const numPassages = Math.ceil(questions.length / questionsPerPassage);

      for (let i = 0; i < numPassages; i++) {
        const startIdx = i * questionsPerPassage;
        const endIdx = Math.min(startIdx + questionsPerPassage, questions.length);
        const passageQuestions = questions.slice(startIdx, endIdx);

        results.push({
          passage: i === 0 ? passage : null, // Only first group gets the passage
          questions: passageQuestions,
          context: `${context} - Part ${i + 1}`,
          year: year
        });
      }
    }
  } else {
    // No passage found, just questions
    results.push({
      passage: null,
      questions: questions,
      context: context,
      year: year
    });
  }

  return results;
}

function parsePart3_2025(text, year, partHeader) {
  const results = [];

  // For 2025 Part 3, questions 31-40 have a fill-in passage
  // Look for questions 31-40 and extract the passage that comes before them
  const q31Match = text.search(/(^|\n)\s*31[\).\s]/m);
  let fillInPassage = null;
  let questionsText = text;

  if (q31Match > 0) {
    const lead = text.slice(0, q31Match).trim();
    // Look for fill-in indicators or substantial text
    if (lead.length > 50 && (lead.toLowerCase().includes('complète') || lead.toLowerCase().includes('fill') || lead.includes('___'))) {
      fillInPassage = lead;
      questionsText = text.slice(q31Match);
    }
  }

  // Parse questions 31-40
  const questions = parseQuestionsFromText(questionsText, year);
  const part3Questions = questions.filter(q => q.questionNumber >= 31 && q.questionNumber <= 40);

  if (fillInPassage && part3Questions.length > 0) {
    results.push({
      passage: fillInPassage,
      questions: part3Questions,
      context: `${partHeader} - Fill-in Passage`,
      year: year
    });
  } else {
    // No fill-in passage found, treat as regular questions
    results.push({
      passage: null,
      questions: part3Questions,
      context: partHeader,
      year: year
    });
  }

  // Handle any remaining questions (if any)
  const remainingQuestions = questions.filter(q => q.questionNumber < 31 || q.questionNumber > 40);
  if (remainingQuestions.length > 0) {
    results.push({
      passage: null,
      questions: remainingQuestions,
      context: `${partHeader} - Other Questions`,
      year: year
    });
  }

  return results;
}

function parseQuestionsFromText(text, year) {
  const questions = [];

  // Find all question start positions - more flexible pattern
  const questionStarts = [];
  // Look for patterns like: "1.", "2)", "3 ", "TEXTE 1:", etc.
  const regex = /(\d{1,2})([\.\)\s:]|\s*$)/g;
  let match;

  console.log(`parseQuestionsFromText: text length ${text.length}, starts with: ${text.substring(0, 100)}...`);

  while ((match = regex.exec(text)) !== null) {
    const num = parseInt(match[1], 10);

    // Only consider questions 1-40
    if (num >= 1 && num <= 40) {
      questionStarts.push({
        position: match.index,
        number: num,
        fullMatch: match[0]
      });
      console.log(`Found question start: ${num} at position ${match.index}`);
    }
  }

  // Also look for "TEXTE X:" patterns
  const texteRegex = /TEXTE\s+(\d{1,2}):/gi;
  while ((match = texteRegex.exec(text)) !== null) {
    const num = parseInt(match[1], 10);
    if (num >= 1 && num <= 40) {
      questionStarts.push({
        position: match.index,
        number: num,
        fullMatch: match[0],
        isTexte: true
      });
    }
  }

  // Remove duplicates (keep the first occurrence of each question number)
  const seen = new Set();
  const uniqueStarts = questionStarts.filter(start => {
    if (seen.has(start.number)) {
      return false;
    }
    seen.add(start.number);
    return true;
  });

  // Sort by position
  uniqueStarts.sort((a, b) => a.position - b.position);

  // Process each question
  for (let i = 0; i < uniqueStarts.length; i++) {
    const start = uniqueStarts[i];
    const end = i < uniqueStarts.length - 1 ? uniqueStarts[i + 1].position : text.length;

    // Extract the question block
    const questionBlock = text.substring(start.position, end).trim();

    // Remove the question number prefix - handle different formats
    let body = questionBlock;
    if (start.isTexte) {
      // For "TEXTE X:" format, remove the "TEXTE X:" part
      body = body.replace(/^TEXTE\s+\d{1,2}:\s*/i, '').trim();
    } else {
      // For "X.", "X)", "X " formats
      body = body.replace(/^\s*\d{1,2}[\.\)\s:]+\s*/, '').trim();
    }

    // Skip if this looks like an answer line
    if (body.match(/^[A-D][\.\)]?/i) && body.length < 20) {
      continue;
    }

    // Extract question text and options
    let questionText = '';
    let options = [];

    // First try inline extraction on the entire body
    const inlineExtracted = extractInlineOptions(body);
    if (inlineExtracted) {
      questionText = inlineExtracted.question;
      options = inlineExtracted.options;
    } else {
      // Fallback: Split body into lines (but since it's one line, split by option markers)
      const parts = body.split(/(?=[A-D][\.\)\s])/);
      if (parts.length > 1) {
        // First part is question text
        questionText = parts[0].trim();
        // Remaining parts are options
        for (let j = 1; j < parts.length; j++) {
          const optMatch = parts[j].match(/^([A-D])(?:\.|\)|\s|[-–—:])\s*(.+)$/i);
          if (optMatch) {
            options.push(optMatch[2].trim());
          }
        }
      } else {
        // No clear options found - check if this is the newer format (2010+) with space-separated options
        const words = body.split(/\s+/).filter(w => w.length > 0);
        if (words.length === 4 && !body.includes('.') && !body.includes('A.') && !body.includes('B.')) {
          // This looks like the newer format: "son sa ton ta" - four space-separated options
          questionText = ''; // No question text for fill-in questions
          options = words;
        } else {
          // No clear options found, treat whole body as question text
          questionText = body;
        }
      }
    }

    // Clean up question text
    questionText = questionText.replace(/\s+/g, ' ').trim();

    // Only add if we have a valid question
    // For fill-in questions (1-10 in newer format), options are sufficient even without question text
    if ((questionText && options.length >= 1) || (options.length >= 1 && start.number >= 1 && start.number <= 10) || (start.number >= 31 && start.number <= 40)) {
      questions.push({
        questionNumber: start.number,
        questionText,
        options,
        _removedLeadingChoice: false
      });
    }
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
    // result.passagesAndQuestions is now an array of {passage, questions, context, year}
    for (const item of result.passagesAndQuestions) {
      if (item.passage && item.questions.length > 0) {
        const year = item.year || result.docs?.[0]?.year;
        const passageId = `french_${year}_${item.context.replace(/\s+/g, '_').toLowerCase()}`.replace(/[^a-z0-9_]/g, '_');

        const passageRef = db.collection('french_passages').doc(passageId);

        const passageData = {
          id: passageId,
          title: `French ${item.context}`,
          content: item.passage,
          subject: 'french',
          examType: 'bece',
          year: year,
          section: 'COMPREHENSION',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'french_import',
          isActive: true
        };

        passageBatch.set(passageRef, passageData);
        passageCount++;

        // Add passageId to all questions in this group
        item.questions.forEach(q => {
          q.passageId = passageId;
        });
      }
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
    // Flatten all questions from all passage groups
    const allQuestions = result.passagesAndQuestions.flatMap(item => item.questions);

    for (const question of allQuestions) {
      // Skip documents with missing required fields
      if (!question.questionNumber || !question.questionText) {
        console.warn(`Skipping question with missing data: qNum=${question.questionNumber}`);
        continue;
      }

      const year = result.year || question.year;
      if (!year) {
        console.warn(`Skipping question with no year: qNum=${question.questionNumber}`);
        continue;
      }

      const id = `french_${year}_${question.questionNumber}`.replace(/\s+/g, '_').toLowerCase();
      const docRef = db.collection('french_questions').doc(id);

      const payload = {
        subject: 'french',
        year: year,
        examType: 'bece',
        section: 'COMPREHENSION',
        questionNumber: question.questionNumber,
        questionText: question.questionText,
        options: question.options,
        displayOptions: question.options.map((o, i) => `${String.fromCharCode(65 + i)}. ${o}`),
        correctAnswer: question.correctAnswer,
        passageId: question.passageId || null,
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

  const { passagesAndQuestions } = splitQuestionsFromText(raw, year);

  return {
    passagesAndQuestions,
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
      const { passagesAndQuestions, year, fileName } = await processFile(f);

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

      // Merge answers into all questions
      passagesAndQuestions.forEach(item => {
        item.questions.forEach(q => {
          q.correctAnswer = answersMap[q.questionNumber] || null;
        });
      });

      // Save to JSON for debugging/review
      const outPath = path.join(outDir, `${fileName}.json`);
      fs.writeFileSync(outPath, JSON.stringify(passagesAndQuestions, null, 2), 'utf8');
      console.log(`Wrote ${passagesAndQuestions.reduce((sum, item) => sum + item.questions.length, 0)} questions to ${outPath}`);

      results.push({ file: f, passagesAndQuestions, year });

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