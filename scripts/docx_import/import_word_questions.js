#!/usr/bin/env node
/**
 * import_word_questions.js
 *
 * Usage examples (PowerShell):
 * 1) Convert DOCX files to JSON (dry run):
 *    cd scripts\docx_import; npm install; node import_word_questions.js --folder "..\\..\\assets\\bece french" --out ../output --dry
 *
 * 2) Convert and import to Firestore using a service account:
 *    cd scripts\docx_import; npm install; node import_word_questions.js --folder "..\\..\\assets\\bece french" --out ../output --import --serviceAccountPath "..\\..\\uriel-academy-...json"
 *
 * Notes:
 * - This is a best-effort parser using heuristics. Review generated JSON before importing.
 * - The script supports passages: text before question 1 is considered a passage if it's >120 chars.
 */

const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');
const {Buffer} = require('buffer');

function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach((a) => {
    if (a.startsWith('--')) {
      const [k, v] = a.replace(/^--/, '').split('=');
      args[k] = v === undefined ? true : v;
    }
  });
  return args;
}

function readDirDocx(folder) {
  const files = fs.readdirSync(folder || '.');
  return files.filter(f => f.toLowerCase().endsWith('.docx')).map(f => path.join(folder, f));
}

async function docxToText(filePath) {
  const result = await mammoth.extractRawText({path: filePath});
  return result.value; // plain text
}

async function extractImagesFromDocx(filePath) {
  // Convert to HTML with inline images as data: URIs
  const result = await mammoth.convertToHtml({path: filePath}, {
    convertImage: mammoth.images.inline(function(element) {
      return element.read('base64').then(function(imageBuffer) {
        return {src: `data:${element.contentType};base64,${imageBuffer}`};
      });
    })
  });

  const html = result.value || '';
  const dataUriRegex = /<img[^>]+src=["'](data:([^"']+))["'][^>]*>/ig;
  const images = [];
  let m;
  while ((m = dataUriRegex.exec(html)) !== null) {
    const full = m[1]; // data:image/png;base64,....
    const parts = full.split(',');
    if (parts.length !== 2) continue;
    const header = parts[0];
    const b64 = parts[1];
    const contentType = header.split(';')[0].replace('data:', '');
    const buffer = Buffer.from(b64, 'base64');
    images.push({contentType, buffer});
  }
  return images;
}

function splitQuestionsFromText(text) {
  // Normalize newlines
  text = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // Remove repeated multiple newlines
  text = text.replace(/\n{3,}/g, '\n\n');

  // Heuristic: treat leading block as passage if it's long
  let passage = null;
  const firstQuestionMatch = text.search(/(^|\n)\s*1[\).\s]/m);
  if (firstQuestionMatch > 0) {
    const lead = text.slice(0, firstQuestionMatch).trim();
    if (lead.length > 120) passage = lead;
    text = text.slice(firstQuestionMatch);
  }

  // Split on question numbers like `1. ` or `1)` or `1 ` at line starts
  const parts = text.split(/(^|\n)\s*(?=\d{1,2}[\).]\s+)/m).filter(Boolean).join('');

  // Now find each question by a regex global match
  const qRegex = /(?:^|\n)\s*(\d{1,2})[\).]\s*([\s\S]*?)(?=(?:\n\s*\d{1,2}[\).]\s)|$)/g;
  const questions = [];
  let m;
  while ((m = qRegex.exec(text)) !== null) {
    const num = parseInt(m[1], 10);
    let body = m[2].trim();

    // Options: lines starting with A. or A)
    const lines = body.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    let options = [];
    let questionLines = [];
    // Accept a wider set of delimiters used in French documents: '.', ')', '-', ':', em-dash, or plain space
    const perLineOptRegex = /^([A-D])(?:\.|\)|\s|[-–—:])\s*(.+)$/i;
    lines.forEach(line => {
      const optMatch = line.match(perLineOptRegex);
      if (optMatch) {
        options.push(optMatch[2].trim());
      } else {
        questionLines.push(line);
      }
    });

    // If options are not found inline or as separate lines, try to extract inline options from the combined questionText
    function extractInlineOptionsFromString(s) {
      // Robust inline options detection. Handles patterns like:
      // '...A. option1 B. option2 C. option3 D. option4' (with or without newlines/spaces)
      // Also handles lowercase letters and parentheses.
      const hasLabel = /[A-Da-d][\.\)\s]/.test(s);
      if (!hasLabel) return null;
      // Normalize spacing: insert a space after option label if missing (e.g. 'A.de' -> 'A. de')
      // Also normalize variants like 'A-' or 'A:' to 'A.' for easier splitting
      const normalized = s.replace(/([A-Da-d])(?:[\.\)\-–—:])(?=[A-Za-z0-9])/g, '$1. ');
      // Split before each option label (A-D)
      const parts = normalized.split(/(?=[A-Da-d][\.\)])/g).map(p => p.trim()).filter(Boolean);
      if (parts.length < 2) return null;
      // First part may still contain trailing question text
      const qpartCandidate = parts.shift();
      // If the first part actually starts with a label (rare), strip it
      const qpart = qpartCandidate.replace(/^[A-Da-d][\.\)]\s*/i, '').trim();
      const opts = parts.map(p => p.replace(/^[A-Da-d][\.\)]\s*/i, '').trim()).filter(Boolean);
      if (opts.length === 0) return null;
      return { question: qpart, options: opts };
    }

    // If options are not found inline, try to split by variants of 'A.' or 'A-' at line starts inside body
    if (options.length === 0) {
      // try structured alt split first, accept different delimiters after the label
      const alt = body.split(/\n\s*A\s*(?:[\.\)\-–—:])/i);
      if (alt.length > 1) {
        const qtext = alt.shift().trim();
        const optionsText = alt.join('A.').trim();
        const optParts = optionsText.split(/\n\s*(?=[B-D]\s*(?:[\.\)\-–—:]))/i).map(p => p.replace(/^[A-D]\s*(?:[\.\)\-–—:])\s*/i, '').trim()).filter(Boolean);
        if (optParts.length > 0) {
          options.push(...optParts);
          questionLines = qtext.split('\n').map(s => s.trim()).filter(Boolean);
        }
      } else {
        // try single-line inline detection
        const extracted = extractInlineOptionsFromString(body);
        if (extracted) {
          options.push(...extracted.options);
          questionLines = [extracted.question];
        }
      }
    }

    // Fallback heuristic: if still no labeled options, and the question body contains
    // multiple short trailing lines (common when DOCX columns/bullets became separate lines),
    // treat the last 4 short lines as options.
    if (options.length === 0) {
      const allLines = body.split('\n').map(s => s.trim()).filter(Boolean);
      if (allLines.length >= 4) {
        const candidate = allLines.slice(-4);
        const isShort = candidate.every(l => l.length > 0 && l.length < 200 && !/^[0-9]+[\).]/.test(l));
        if (isShort) {
          options.push(...candidate);
          questionLines = allLines.slice(0, allLines.length - 4);
        }
      }
    }

    // Special-case: some files (Creative Art & Design) begin a question with an instruction like
    // 'Read the scenario' followed by unlabeled option lines. If detected, move following short lines
    // into options and clear question text.
    if ((questionLines && questionLines.length > 0) && /^\s*read\s+(the\s+)?(scenario|passage|text|following|extract)/i.test(questionLines[0])) {
      const remaining = questionLines.slice(1).filter(Boolean);
      if (remaining.length >= 2 && remaining.length <= 6 && remaining.every(l => l.length < 200)) {
        options = remaining.map(l => l.replace(/^[A-D]\s*[\.\)\-–—:]?\s*/i, '').trim());
        questionLines = [];
      }
    }

    // If still no options, but questionLines itself contains multiple short lines (unlabeled options),
    // treat them as options.
    if ((options.length === 0) && questionLines.length >= 2 && questionLines.length <= 6 && questionLines.every(l => l.length < 200)) {
      options = questionLines.map(l => l.replace(/^[A-D]\s*[\.\)\-–—:]?\s*/i, '').trim());
      questionLines = [];
    }

    // If existing options contain a single entry that itself contains multiple candidates separated by
    // semicolons, slashes or multiple spaces, attempt to split into separate options.
    if (options.length === 1) {
      const single = options[0];
      // detect separators commonly produced by DOCX->text
      if (/[;\/\|\t]{1,}|\s{2,}/.test(single)) {
        const parts = single.split(/[;\/\|\t]|\s{2,}/).map(p => p.trim()).filter(Boolean);
        if (parts.length >= 2 && parts.length <= 6) {
          options = parts;
        }
      }
    }
    
    let questionText = questionLines.join(' ');

    // Heuristic: sometimes DOCX -> text places the option words as a short space-separated
    // token list in the question text (e.g. 'son sa ton ta'). If we detect 4 short words and
    // no labeled options, treat them as options and clear the questionText.
    if ((!options || options.length === 0) && questionText && /^[A-Za-zÀ-ÖØ-öø-ÿ'’\-]+(\s+[A-Za-zÀ-ÖØ-öø-ÿ'’\-]+){3,}$/i.test(questionText.trim())) {
      const parts = questionText.trim().split(/\s+/).map(p => p.trim()).filter(Boolean);
      if (parts.length >= 4 && parts.length <= 8) {
        options = parts;
        questionText = '';
      }
    }

    // If first option looks like a duplicated question/prompt (very long and contains 'Which'/'Select'),
    // move it into the questionText and remove from options. Mark removal so answer letters can be adjusted.
    let removedLeadingChoice = false;
    if (options && options.length > 0) {
      const first = options[0] || '';
      if (first.length > 60 && /\b(Which|Select|Choose|Identify|Select the|Which of the following)\b/i.test(first)) {
        // attach to questionText
        questionText = ((questionText || '') + ' ' + first).trim();
        options = options.slice(1);
        removedLeadingChoice = true;
      }
    }

    questions.push({ questionNumber: num, questionText, options, _removedLeadingChoice: removedLeadingChoice });
  }

  return { passage, questions };
}

function tryParseAnswersFromText(text) {
  // Find lines like `1 A` or `1. A` or `1) A.` or `1 - A`
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  const answers = {};
  lines.forEach(l => {
    const m = l.match(/^(\d{1,2})[\)\.\-\s]*([A-D])[\.\)]?/i);
    if (m) answers[parseInt(m[1], 10)] = m[2].toUpperCase();
  });
  return answers;
}

async function processFile(filePath) {
  const raw = await docxToText(filePath);
  const { passage, questions } = splitQuestionsFromText(raw);
  return { passage, questions };
}

async function processAnswersFile(filePath) {
  const raw = await docxToText(filePath);
  return tryParseAnswersFromText(raw);
}

function mergeAnswers(questions, answersMap) {
  return questions.map(q => {
    let ans = answersMap && answersMap[q.questionNumber];
    // If we removed a leading dummy choice earlier, shift the letter back by one (e.g. C->B)
    if (ans && q._removedLeadingChoice && /^[A-Z]$/i.test(ans)) {
      const code = ans.toUpperCase().charCodeAt(0);
      if (code <= 65) {
        // cannot shift A back; drop answer to null so it can be reviewed
        ans = null;
      } else {
        ans = String.fromCharCode(code - 1);
      }
    }
    return Object.assign({}, q, { correctAnswer: ans || null });
  });
}

async function importToFirestore(docs, serviceAccountPath) {
  const admin = require('firebase-admin');
  const sa = require(path.resolve(serviceAccountPath));
  // Avoid re-initialization in case called multiple times
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), storageBucket: sa.project_id + '.appspot.com' });
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  for (const doc of docs) {
    const id = `${doc.subject}_${doc.year}_q${doc.questionNumber}`.replace(/\s+/g, '_').toLowerCase();
    const docRef = db.collection('questions').doc(id);

    try {
      const existing = await docRef.get();
      const skipExisting = !!process.argv.find(a => a.includes('--skipExisting'));
      const force = !!process.argv.find(a => a.includes('--force'));
      if (existing.exists && skipExisting && !force) {
        console.log('Skipping existing:', id);
        continue;
      }

      // Build payload with app-compatible fields
      const payload = Object.assign({}, doc, {
        id: id,
        type: 'multipleChoice',
        marks: doc.marks || 1,
        difficulty: doc.difficulty || 'medium',
        topics: doc.topics || [],
        explanation: doc.explanation || null,
        isActive: typeof doc.isActive === 'boolean' ? doc.isActive : true,
        createdBy: 'docx_import'
      });

      // If image buffers are present in metadata, upload them to Storage
      if (doc.metadata && Array.isArray(doc.metadata.imageBuffers) && doc.metadata.imageBuffers.length > 0) {
        const uploaded = [];
        for (let i = 0; i < doc.metadata.imageBuffers.length; i++) {
          const img = doc.metadata.imageBuffers[i];
          try {
            const ext = (img.contentType || 'image/png').split('/').pop();
            const storagePath = `question_images/${id}/${i}.${ext}`;
            const file = bucket.file(storagePath);
            await file.save(img.buffer, { metadata: { contentType: img.contentType || 'image/png' } });
            try { await file.makePublic(); } catch (e) { /* ignore permission errors */ }
            const publicUrl = `https://storage.googleapis.com/${bucket.name}/${encodeURIComponent(storagePath)}`;
            uploaded.push(publicUrl);
          } catch (e) {
            console.error('Image upload failed for', id, e && e.message ? e.message : e);
          }
        }
        if (uploaded.length > 0) {
          // attach first uploaded image as imageAfterQuestion for now
          payload.imageAfterQuestion = payload.imageAfterQuestion || uploaded[0];
          payload.optionImages = payload.optionImages || {};
          payload.metadata = payload.metadata || {};
          payload.metadata.uploadedImages = uploaded;
        }
      }

      // write to Firestore (overwrite if force true)
      await docRef.set(Object.assign(payload, { createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
      console.log('Imported:', id);
    } catch (e) {
      console.error('Failed to import', id, e && e.message ? e.message : e);
    }
  }
}

async function main() {
  const args = parseArgs();
  const folder = args.folder || args.f || path.join(__dirname, '..', '..', 'assets', 'bece french');
  const outDir = args.out ? path.resolve(args.out) : path.join(__dirname, '..', 'output');
  const doImport = !!args.import;
  const serviceAccountPath = args.serviceAccountPath || args.s;

  if (!fs.existsSync(folder)) {
    console.error('Folder not found:', folder);
    process.exit(1);
  }

  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const docxFiles = readDirDocx(folder);
  // Preload any answers/key files in the folder so we can merge answers heuristically
  const answersFiles = docxFiles.filter(x => /answer|key/i.test(path.basename(x)));
  let masterAnswersMap = {};
  for (const af of answersFiles) {
    try {
      const raw = await docxToText(af);
      const map = tryParseAnswersFromText(raw);
      masterAnswersMap = Object.assign(masterAnswersMap, map);
      const outPath = path.join(outDir, path.basename(af, '.docx') + '.answers.json');
      fs.writeFileSync(outPath, JSON.stringify(map, null, 2), 'utf8');
      console.log('Preloaded answers from', path.basename(af));
    } catch (e) {
      console.warn('Failed to read answers file', af, e && e.message ? e.message : e);
    }
  }

  if (docxFiles.length === 0) {
    console.log('No .docx files found in', folder);
    return;
  }

  const results = [];
  for (const f of docxFiles) {
    console.log('Processing', f);
    try {
      const base = path.basename(f, '.docx');
      const rawText = await docxToText(f);
      // try to detect answers file by name
      const isAnswers = /answer/i.test(base);
      if (isAnswers) {
        // store as answers doc for sibling mapping
        const answersMap = tryParseAnswersFromText(rawText);
        const outPath = path.join(outDir, base + '.answers.json');
        fs.writeFileSync(outPath, JSON.stringify(answersMap, null, 2), 'utf8');
        console.log('Wrote answers map to', outPath);
        continue;
      }

      const { passage, questions } = splitQuestionsFromText(rawText);

      // if images flag provided, extract images buffers for this file
      if (args.images) {
        try {
          const imgs = await extractImagesFromDocx(f);
          if (imgs && imgs.length > 0) {
            // attach image buffers to metadata so importer can upload
            // We'll add them to the per-file docs later
            // store temporarily on a local variable
            var fileImageBuffers = imgs; // eslint-disable-line no-var
            console.log('  -> Found', imgs.length, 'images in', path.basename(f));
          }
        } catch (e) {
          console.error('  -> Image extraction failed for', f, e && e.message ? e.message : e);
        }
      }

      // attempt to find a matching answers file in folder (prefer preloaded masterAnswersMap)
      let answersMap = null;
      if (masterAnswersMap && Object.keys(masterAnswersMap).length) {
        answersMap = masterAnswersMap;
      } else {
        const answersCandidate = docxFiles.find(x => path.basename(x).toLowerCase().includes(base.toLowerCase().replace(/questions/g, 'answers')));
        if (answersCandidate) {
          try {
            answersMap = await processAnswersFile(answersCandidate);
            console.log('Found answers file for', base);
          } catch (e) { /* ignore */ }
        }
      }

      // normalize question numbers: ensure unique sequence
      const deduped = [];
      const seen = new Set();
      const merged = mergeAnswers(questions, answersMap);
      for (const q of merged) {
        const key = `${q.questionNumber}`;
        if (seen.has(key)) {
          // if duplicate, try to increment until unique
          let n = q.questionNumber;
          while (seen.has(String(n))) n++;
          q.questionNumber = n;
        }
        seen.add(String(q.questionNumber));
        deduped.push(q);
      }

      // move any in-line "Read the passage" blocks from questionText into passage
      deduped.forEach(q => {
        const markerMatch = q.questionText && q.questionText.match(/read the passage[\s\S]*/i);
        if (markerMatch) {
          const marker = markerMatch[0];
          // find start index in raw text to use as passage if available
          const idx = markerMatch.index || 0;
          // set passage if not already
          if (!passage || passage.length < marker.length) passage = marker.trim();
          q.questionText = q.questionText.replace(marker, '').trim();
        }
      });

      const mergedFinal = deduped;

      // Build JSON objects per question for potential import
      const outDocs = mergedFinal.map(q => {
        // normalize options: try to ensure exactly 4 where possible
        let opts = Array.isArray(q.options) ? q.options.map(o => (o || '').trim()).filter(Boolean) : [];

        // If there's a single long option that contains separators, try to split it
        if (opts.length === 1) {
          const single = opts[0];
          const parts = single.split(/[;\/\|\t]|\s{2,}/).map(p => p.trim()).filter(Boolean);
          if (parts.length >= 2 && parts.length <= 6) opts = parts;
        }

        // If we still don't have 4 but questionText contains a short space-separated list and options empty,
        // attempt to extract from questionText (covers 'son sa ton ta' style cloze lists)
        if ((opts.length === 0 || opts.length < 4) && q.questionText && /^[A-Za-zÀ-ÖØ-öø-ÿ'’\-]+(\s+[A-Za-zÀ-ÖØ-öø-ÿ'’\-]+){3,}$/i.test(q.questionText.trim())) {
          const parts = q.questionText.trim().split(/\s+/).map(p => p.trim()).filter(Boolean);
          if (parts.length >= 4 && parts.length <= 8) {
            opts = parts.slice(0, 4);
            // clear questionText cloze tokens
            q.questionText = '';
          }
        }

        // If still fewer than 4, try to pull unlabeled short lines from the original parsing (if available)
        if (opts.length < 4 && q._rawLines && Array.isArray(q._rawLines)) {
          const extra = q._rawLines.map(l => l.trim()).filter(Boolean).slice(0, 4 - opts.length);
          opts = opts.concat(extra);
        }

        // Final padding to ensure length 4 (use empty string placeholders)
        while (opts.length < 4) opts.push('');

        // If more than 4, truncate to 4
        if (opts.length > 4) opts = opts.slice(0, 4);

        // Build labeled displayOptions (A-D)
        const displayOptions = opts.map((o, i) => `${String.fromCharCode(65 + i)}. ${o}`);

        return {
          subject: path.basename(folder).toLowerCase().includes('french') ? 'french' : (path.basename(folder).toLowerCase().includes('career technology') ? 'career_technology' : path.basename(folder).toLowerCase().includes('creative art') ? 'creativeArts' : 'unknown'),
          year: (base.match(/(19|20)\d{2}/) || [''])[0] || null,
          examType: 'bece',
          section: 'A',
          questionNumber: q.questionNumber,
          questionText: q.questionText,
          options: opts,
          displayOptions: displayOptions,
          correctAnswer: q.correctAnswer || null,
          passage: passage || null,
          metadata: { sourceFile: path.basename(f), importedAt: new Date().toISOString() }
        };
      });

      // If fileImageBuffers exists, attach to each doc's metadata so import can upload
      if (typeof fileImageBuffers !== 'undefined' && fileImageBuffers && fileImageBuffers.length > 0) {
        outDocs.forEach(d => {
          d.metadata = d.metadata || {};
          d.metadata.imageBuffers = fileImageBuffers;
        });
      }

      const outPath = path.join(outDir, base + '.json');
      fs.writeFileSync(outPath, JSON.stringify(outDocs, null, 2), 'utf8');
      console.log('Wrote', outPath, 'questions:', outDocs.length);
      results.push({ file: f, out: outPath, count: outDocs.length, docs: outDocs });
    } catch (err) {
      console.error('Error processing', f, err && err.stack ? err.stack : err);
    }
  }

  // Generate verification report for any questions with missing options or missing answers
  const report = [];
  results.forEach(r => {
    r.docs.forEach(d => {
      const issues = [];
      // Prefer exactly 4 options for MCQs
      if (!d.options || d.options.length !== 4) issues.push('not_4_options');
      if (!d.correctAnswer) issues.push('missing_correctAnswer');
      if (issues.length > 0) {
        report.push({ sourceFile: r.file, questionNumber: d.questionNumber, issues, subject: d.subject, year: d.year });
      }
    });
  });
  if (report.length > 0) {
    const repDir = path.join(__dirname, '..', 'reports');
    if (!fs.existsSync(repDir)) fs.mkdirSync(repDir, { recursive: true });
    const repPath = path.join(repDir, `verification_report_${Date.now()}.json`);
    fs.writeFileSync(repPath, JSON.stringify(report, null, 2), 'utf8');
    console.log('Verification report written to', repPath, 'issues found:', report.length);
  } else {
    console.log('No parsing issues detected in verification pass');
  }

  if (doImport) {
    if (!serviceAccountPath) {
      console.error('--import was requested but --serviceAccountPath was not provided. Aborting import.');
      process.exit(2);
    }
    // Flatten all docs
    const allDocs = [];
    results.forEach(r => r.docs.forEach(d => allDocs.push(d)));
    if (allDocs.length === 0) {
      console.log('No docs to import.');
      return;
    }
    console.log('Importing', allDocs.length, 'documents to Firestore...');
    await importToFirestore(allDocs, serviceAccountPath);
    console.log('Import complete.');
  } else {
    console.log('Dry run complete. Use --import and --serviceAccountPath to write to Firestore.');
  }
}

main().catch(e => { console.error(e && e.stack ? e.stack : e); process.exit(1); });
