#!/usr/bin/env node
/**
 * Import JHS Social Studies JSONL into Firestore `docs` collection with embeddings.
 *
 * Requirements:
 * - Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON with Firestore access.
 * - Set OPENAI_API_KEY to an OpenAI API key.
 *
 * Usage: node scripts/import_jhs_social_studies_to_docs.js
 *
 * The script will write a report to scripts/output/import_social_studies_report.json
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

async function main() {
  const projectRoot = path.join(__dirname, '..');
  const jsonlPath = path.join(projectRoot, 'assets', 'curriculum', 'jhs curriculum', 'social studies', 'social-studies-ccp-rag-v2.jsonl');
  const outDir = path.join(__dirname, 'output');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const reportPath = path.join(outDir, 'import_social_studies_report.json');

  const args = process.argv.slice(2);
  const NO_EMBED = args.includes('--no-embeddings');
  const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
  if (!NO_EMBED && !OPENAI_API_KEY) {
    console.error('Missing OPENAI_API_KEY environment variable. Set it and re-run, or run with --no-embeddings to import without embeddings.');
    process.exit(2);
  }

  // Initialize Firebase Admin using application default credentials
  // Initialize Firebase Admin.
  // Prefer a service account JSON placed in repo root (if present). Otherwise fall back to ADC.
  const candidates = fs.readdirSync(projectRoot).filter(f => f.endsWith('.json') && f.toLowerCase().includes('firebase-adminsdk'));
  if (candidates.length > 0) {
    const saPath = path.join(projectRoot, candidates[0]);
    console.log('Using service account JSON at', saPath);
    try {
      const sa = require(saPath);
      console.log('Detected service account project_id:', sa.project_id || 'unknown');
      admin.initializeApp({ credential: admin.credential.cert(sa), projectId: sa.project_id });
    } catch (ee) {
      console.error('Failed to initialize Admin SDK with detected service account JSON:', ee && ee.stack ? ee.stack : ee);
      process.exit(2);
    }
  } else {
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
      });
    } catch (e) {
      console.error('Failed to initialize Firebase Admin via Application Default Credentials. Ensure GOOGLE_APPLICATION_CREDENTIALS is set.');
      console.error(e && e.stack ? e.stack : e);
      process.exit(2);
    }
  }

  const db = admin.firestore();

  if (!fs.existsSync(jsonlPath)) {
    console.error('JSONL file not found at', jsonlPath);
    process.exit(1);
  }

  const lines = fs.readFileSync(jsonlPath, 'utf8').split(/\r?\n/).filter(Boolean);

  console.log(`Found ${lines.length} lines in ${jsonlPath}`);

  const report = { totalLines: lines.length, processed: 0, skipped: 0, errors: [], created: [] };

  // Helper: pause
  const sleep = ms => new Promise(r => setTimeout(r, ms));

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    let row;
    try {
      row = JSON.parse(raw);
    } catch (e) {
      report.errors.push({ line: i + 1, error: 'JSON parse error', detail: e.message });
      continue;
    }

    // Build document id
    const baseId = (row.id || row.sub_id || row.chunk_id || `line_${i+1}`).toString().replace(/[^a-zA-Z0-9_-]/g, '_');
    const docId = `socialstudies_${baseId}`;

    try {
      // Check if doc exists
      const existing = await db.collection('docs').doc(docId).get();
      if (existing.exists) {
        report.skipped++;
        continue;
      }

      // Build text to embed
      const parts = [];
      if (row.title) parts.push(row.title);
      if (row.text) parts.push(row.text);
      if (row.exemplars_text) parts.push(row.exemplars_text);
      if (row.teacherChecklist) parts.push(row.teacherChecklist);
      if (row.glossary) parts.push(row.glossary);
      if (row.competencies) parts.push(Array.isArray(row.competencies) ? row.competencies.join(' | ') : String(row.competencies || ''));

      const text = parts.filter(Boolean).join('\n\n').trim();
      if (!text) {
        report.errors.push({ line: i + 1, error: 'No text to embed', id: docId });
        continue;
      }

      let vector = null;
      if (!NO_EMBED) {
        // Create embedding using OpenAI embeddings endpoint
        const resp = await fetch('https://api.openai.com/v1/embeddings', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${OPENAI_API_KEY}`
          },
          body: JSON.stringify({ model: 'text-embedding-3-small', input: text })
        });

        if (!resp.ok) {
          const body = await resp.text();
          report.errors.push({ line: i + 1, error: 'OpenAI API error', status: resp.status, body });
          console.error('OpenAI error', resp.status, body);
          // Try to continue after a short pause
          await sleep(500);
          continue;
        }

        const j = await resp.json();
        vector = j?.data?.[0]?.embedding;
        if (!vector || !Array.isArray(vector)) {
          report.errors.push({ line: i + 1, error: 'No embedding returned', id: docId, raw: j });
          continue;
        }
      }

      const doc = {
        title: row.title || null,
        text: row.text || null,
        exemplars_text: row.exemplars_text || null,
        metadata: row.metadata || null,
        source: 'assets/curriculum/jhs curriculum/social studies/social-studies-ccp-rag-v2.jsonl',
        chunkId: row.sub_id || row.id || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        embedding: vector,
        embeddingUpdatedAt: vector ? admin.firestore.FieldValue.serverTimestamp() : null,
        embeddingPending: vector ? false : true,
        type: 'jsonl_social_studies'
      };

      await db.collection('docs').doc(docId).set(doc);
      report.created.push({ line: i + 1, id: docId });
      report.processed++;

      // rate limit
      await sleep(250);

    } catch (e) {
      report.errors.push({ line: i + 1, error: e.message || String(e) });
    }
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log('Import complete. Report written to', reportPath);
  console.log('Summary:', { total: report.totalLines, processed: report.processed, skipped: report.skipped, errors: report.errors.length });
}

// Ensure fetch is available (Node 18+). If not, polyfill with node-fetch.
if (typeof fetch === 'undefined') {
  try {
    global.fetch = require('node-fetch');
  } catch (e) {
    console.error('Global fetch is not available and node-fetch is not installed. Please run on Node 18+ or install node-fetch.');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Unhandled error in import script:', err && err.stack ? err.stack : err);
  process.exit(1);
});
