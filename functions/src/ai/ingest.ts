import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';
import * as fs from 'fs';
import * as path from 'path';
import * as pdfParse from 'pdf-parse';

// Use admin.firestore() inside the function to avoid init ordering issues
const OPENAI_KEY = functions.config().openai?.key;
const client = new OpenAI({ apiKey: OPENAI_KEY });

// Ingest up to `limit` question docs missing embeddings and compute embeddings.
export const ingestDocs = functions.https.onCall(async (data, context) => {
  // Require admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can run ingestion');
  }

  const limit = Number(data?.limit || 200);
  const snapshot = await admin.firestore().collection('questions').limit(limit).get();
  const toProcess: Array<{ id: string; text: string }> = [];

  snapshot.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => {
    const d: any = doc.data();
    if (!d) return;
    if (d.embedding && Array.isArray(d.embedding) && d.embedding.length > 10) return; // already embedded
    // Build text from question fields
    const pieces: string[] = [];
    if (d.questionText) pieces.push(d.questionText);
    if (d.options && Array.isArray(d.options)) pieces.push(d.options.join(' | '));
    if (d.explanation) pieces.push(d.explanation);
    const text = pieces.join('\n');
    toProcess.push({ id: doc.id, text });
  });

  if (toProcess.length === 0) {
    return { status: 'ok', message: 'No docs to ingest' };
  }

  const results: Array<{ id: string; success: boolean; error?: string }> = [];

  for (const item of toProcess) {
    try {
      const embResp = await client.embeddings.create({ model: 'text-embedding-3-small', input: item.text });
      const vector = embResp.data?.[0]?.embedding as number[] | undefined;
      if (!vector) {
        results.push({ id: item.id, success: false, error: 'No vector returned' });
        continue;
      }
  await admin.firestore().collection('questions').doc(item.id).update({ embedding: vector, embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp() });
      results.push({ id: item.id, success: true });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      results.push({ id: item.id, success: false, error: errMsg });
    }
    // light delay to avoid throttling
    await new Promise(r => setTimeout(r, 200));
  }

  return { status: 'ok', processed: results.length, results };
});

// Extract text from PDF buffer
async function extractTextFromPDF(pdfBuffer: Buffer): Promise<string> {
  try {
    const data = await (pdfParse as any)(pdfBuffer);
    return data.text;
  } catch (error) {
    console.error('Error extracting text from PDF:', error);
    throw new Error('Failed to extract text from PDF');
  }
}

// Split text into chunks for embedding
function splitTextIntoChunks(text: string, chunkSize = 1000, overlap = 200): string[] {
  const chunks: string[] = [];
  let start = 0;

  while (start < text.length) {
    let end = start + chunkSize;
    if (end < text.length) {
      // Find a good breaking point (sentence end)
      const lastPeriod = text.lastIndexOf('.', end);
      const lastNewline = text.lastIndexOf('\n', end);
      const breakPoint = Math.max(lastPeriod, lastNewline);
      if (breakPoint > start + chunkSize * 0.5) {
        end = breakPoint + 1;
      }
    }

    chunks.push(text.slice(start, end).trim());
    start = end - overlap;
  }

  return chunks;
}

// Ingest PDF documents from assets
export const ingestPDFs = functions.https.onCall(async (data, context) => {
  // Require admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can run PDF ingestion');
  }

  const pdfPaths = data?.pdfPaths || [
    'assets/curriculum/jhs curriculum/english-language.pdf',
    'assets/curriculum/jhs curriculum/mathematics-1.pdf',
    'assets/curriculum/jhs curriculum/science.pdf',
    'assets/curriculum/jhs curriculum/social-studies.pdf',
    'assets/curriculum/jhs curriculum/religious-and-moral-education.pdf',
    'assets/curriculum/jhs curriculum/ghanaian-language.pdf',
    'assets/curriculum/jhs curriculum/creative-arts-and-design.pdf',
    'assets/curriculum/jhs curriculum/physical-education-and-health.pdf',
    'assets/curriculum/jhs curriculum/career-technology-k-9-3rd-aug.08.2021.pdf'
  ];

  const results: Array<{ pdfPath: string; success: boolean; chunksProcessed?: number; error?: string }> = [];

  for (const pdfPath of pdfPaths) {
    try {
      console.log(`Processing PDF: ${pdfPath}`);

      // Read PDF from local filesystem (assuming it's in the functions directory or accessible)
      const fullPath = path.join(process.cwd(), '..', pdfPath); // Go up one level from functions/
      const pdfBuffer = fs.readFileSync(fullPath);

      // Extract text
      const pdfText = await extractTextFromPDF(pdfBuffer);

      if (!pdfText || pdfText.trim().length === 0) {
        results.push({ pdfPath, success: false, error: 'No text extracted from PDF' });
        continue;
      }

      // Split into chunks
      const chunks = splitTextIntoChunks(pdfText, 1000, 200);
      console.log(`PDF ${pdfPath} split into ${chunks.length} chunks`);

      let processedChunks = 0;

      // Process chunks in batches to avoid rate limits
      for (let i = 0; i < chunks.length; i += 5) {
        const batch = chunks.slice(i, i + 5);

        for (const chunk of batch) {
          try {
            // Create embedding
            const embResp = await client.embeddings.create({
              model: 'text-embedding-3-small',
              input: chunk
            });
            const vector = embResp.data?.[0]?.embedding as number[];

            if (!vector) {
              console.warn(`No vector returned for chunk ${processedChunks + 1}`);
              continue;
            }

            // Store in Firestore
            const docId = `${pdfPath.replace(/[^a-zA-Z0-9]/g, '_')}_chunk_${processedChunks + 1}`;
            await admin.firestore().collection('docs').doc(docId).set({
              text: chunk,
              embedding: vector,
              source: pdfPath,
              chunkIndex: processedChunks + 1,
              totalChunks: chunks.length,
              type: 'pdf',
              title: path.basename(pdfPath, '.pdf').replace(/-/g, ' ').replace(/_/g, ' '),
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            processedChunks++;

            // Rate limiting
            await new Promise(r => setTimeout(r, 200));

          } catch (e) {
            console.error(`Error processing chunk ${processedChunks + 1}:`, e);
          }
        }
      }

      results.push({ pdfPath, success: true, chunksProcessed: processedChunks });

    } catch (error) {
      const errMsg = error instanceof Error ? error.message : JSON.stringify(error);
      console.error(`Error processing PDF ${pdfPath}:`, errMsg);
      results.push({ pdfPath, success: false, error: errMsg });
    }
  }

  return { status: 'ok', processed: results.length, results };
});

// Ingest PDF documents from local assets (for development/testing)
export const ingestLocalPDFs = functions.https.onCall(async (data, context) => {
  // Require admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can run PDF ingestion');
  }

  const pdfPaths = [
    '../assets/curriculum/jhs curriculum/english-language.pdf',
    '../assets/curriculum/jhs curriculum/mathematics-1.pdf',
    '../assets/curriculum/jhs curriculum/science.pdf',
    '../assets/curriculum/jhs curriculum/social-studies.pdf',
    '../assets/curriculum/jhs curriculum/religious-and-moral-education.pdf',
    '../assets/curriculum/jhs curriculum/ghanaian-language.pdf',
    '../assets/curriculum/jhs curriculum/creative-arts-and-design.pdf',
    '../assets/curriculum/jhs curriculum/physical-education-and-health.pdf',
    '../assets/curriculum/jhs curriculum/career-technology-k-9-3rd-aug.08.2021.pdf'
  ];

  const results: Array<{ pdfPath: string; success: boolean; chunksProcessed?: number; error?: string }> = [];

  for (const pdfPath of pdfPaths) {
    try {
      console.log(`Processing PDF: ${pdfPath}`);

      // Read PDF from local filesystem (assuming it's accessible from functions)
      const fullPath = path.join(__dirname, pdfPath);
      console.log(`Full path: ${fullPath}`);

      if (!fs.existsSync(fullPath)) {
        results.push({ pdfPath, success: false, error: `File not found: ${fullPath}` });
        continue;
      }

      const pdfBuffer = fs.readFileSync(fullPath);

      // Extract text
      const pdfText = await extractTextFromPDF(pdfBuffer);

      if (!pdfText || pdfText.trim().length === 0) {
        results.push({ pdfPath, success: false, error: 'No text extracted from PDF' });
        continue;
      }

      // Split into chunks
      const chunks = splitTextIntoChunks(pdfText, 1000, 200);
      console.log(`PDF ${pdfPath} split into ${chunks.length} chunks`);

      let processedChunks = 0;

      // Process chunks in batches to avoid rate limits
      for (let i = 0; i < chunks.length; i += 5) {
        const batch = chunks.slice(i, i + 5);

        for (const chunk of batch) {
          try {
            // Create embedding
            const embResp = await client.embeddings.create({
              model: 'text-embedding-3-small',
              input: chunk
            });
            const vector = embResp.data?.[0]?.embedding as number[];

            if (!vector) {
              console.warn(`No vector returned for chunk ${processedChunks + 1}`);
              continue;
            }

            // Store in Firestore
            const docId = `${pdfPath.replace(/[^a-zA-Z0-9]/g, '_')}_chunk_${processedChunks + 1}`;
            await admin.firestore().collection('docs').doc(docId).set({
              text: chunk,
              embedding: vector,
              source: pdfPath,
              chunkIndex: processedChunks + 1,
              totalChunks: chunks.length,
              type: 'pdf',
              title: path.basename(pdfPath, '.pdf').replace(/-/g, ' ').replace(/_/g, ' '),
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            processedChunks++;

            // Rate limiting
            await new Promise(r => setTimeout(r, 200));

          } catch (e) {
            console.error(`Error processing chunk ${processedChunks + 1}:`, e);
          }
        }
      }

      results.push({ pdfPath, success: true, chunksProcessed: processedChunks });

    } catch (error) {
      const errMsg = error instanceof Error ? error.message : JSON.stringify(error);
      console.error(`Error processing PDF ${pdfPath}:`, errMsg);
      results.push({ pdfPath, success: false, error: errMsg });
    }
  }

  return { status: 'ok', processed: results.length, results };
});
export const listPDFs = functions.https.onCall(async (data, context) => {
  // Require admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can list PDFs');
  }

  const availablePDFs = [
    'assets/curriculum/jhs curriculum/english-language.pdf',
    'assets/curriculum/jhs curriculum/mathematics-1.pdf',
    'assets/curriculum/jhs curriculum/science.pdf',
    'assets/curriculum/jhs curriculum/social-studies.pdf',
    'assets/curriculum/jhs curriculum/religious-and-moral-education.pdf',
    'assets/curriculum/jhs curriculum/ghanaian-language.pdf',
    'assets/curriculum/jhs curriculum/creative-arts-and-design.pdf',
    'assets/curriculum/jhs curriculum/physical-education-and-health.pdf',
    'assets/curriculum/jhs curriculum/career-technology-k-9-3rd-aug.08.2021.pdf'
  ];

  const pdfStatus: Array<{ path: string; ingested: boolean; chunks?: number; lastUpdated?: string }> = [];

  for (const pdfPath of availablePDFs) {
    try {
      const docId = `${pdfPath.replace(/[^a-zA-Z0-9]/g, '_')}_chunk_1`;
      const doc = await admin.firestore().collection('docs').doc(docId).get();

      if (doc.exists) {
        const data = doc.data();
        // Count total chunks for this PDF
        const chunksQuery = await admin.firestore()
          .collection('docs')
          .where('source', '==', pdfPath)
          .where('type', '==', 'pdf')
          .get();

        pdfStatus.push({
          path: pdfPath,
          ingested: true,
          chunks: chunksQuery.size,
          lastUpdated: data?.createdAt?.toDate?.()?.toISOString() || 'unknown'
        });
      } else {
        pdfStatus.push({
          path: pdfPath,
          ingested: false
        });
      }
    } catch (error) {
      console.error(`Error checking status for ${pdfPath}:`, error);
      pdfStatus.push({
        path: pdfPath,
        ingested: false
      });
    }
  }

  return { status: 'ok', pdfs: pdfStatus };
});

export default { ingestDocs, ingestPDFs, ingestLocalPDFs, listPDFs };
