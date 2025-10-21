import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { scoreExam } from './lib/scoring';
import { hasEntitlement, EntitlementType } from './util/entitlement';
import { ingestDocs, ingestPDFs, ingestLocalPDFs, listPDFs } from './ai/ingest';
import { aiChatHttp } from './ai/http_ai';
import { aiChatHttp as aiChatHttpSimple } from './ai/simple_ai_chat';
import OpenAI from 'openai';
import cors from 'cors';

// Expose the simple HTTP handler under a new named export so we can deploy it
export const aiChatSimple = aiChatHttpSimple;

// Lightweight CORS-safe aiChat HTTP endpoint for Flutter Web clients
// Uses functions.config().openai.key — set with `firebase functions:config:set openai.key="..."`
const openai = new OpenAI({ apiKey: functions.config().openai?.key });

const corsHandler = cors({
  origin: [
    'https://uriel.academy',
    'https://uriel-academy-41fb0.web.app',
    'https://uriel-academy-41fb0.firebaseapp.com',
    'http://localhost:5000',
    'http://localhost:5173',
    'http://localhost:4200',
    'http://localhost:3000'
  ],
  credentials: false,
});

// Model identity and cutoff (update when you change models)
// Prefer the newest GPT model, fall back to a stable 4.x when unavailable.
const MODEL_PRIMARY = 'gpt-5';
const MODEL_FALLBACK = 'gpt-4.1';

// Use a permissive message type to work with the OpenAI client shape
async function chatCompletion(messages: any, temperature = 0.3) {
  // Try primary model first, then fallback if the provider returns an error
  try {
  return await openai.chat.completions.create({ model: MODEL_PRIMARY, temperature, messages });
  } catch (err: any) {
    console.warn(`Primary model ${MODEL_PRIMARY} failed, falling back to ${MODEL_FALLBACK}:`, err?.message ?? err);
  return await openai.chat.completions.create({ model: MODEL_FALLBACK, temperature, messages });
  }
}

// Legacy: 'needsWeb' was replaced by classifyMode -> 'facts' detection.

function classifyMode(q: string): 'small_talk'|'tutoring'|'facts' {
  const s = (q || '').toLowerCase().trim();
  if (/(your name|what'?s your name|who are you|hi|hello|hey|thanks|thank you)\b/.test(s)) return 'small_talk';
  // include common lookup patterns: who is, what is, when is, where is, and topics that need live info
  if (/(who is|who was|what is|where is|when is|when was|date|schedule|latest|today|update|news|bece|wassce|president|minister|result|results|2024|2025|2026)\b/.test(s)) return 'facts';
  return 'tutoring';
}

async function answerWithFacts(query: string) {
  const r = await fetch('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/facts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  if (!r.ok) throw new Error(`facts ${r.status}: ${await r.text()}`);
  const j = await r.json();
  const raw = (j.answer ?? j.reply ?? j.result ?? '').toString();
  // Sanitize the facts response: remove any 'Sources:' block and bracketed domain citations.
  // The UI and user requested that the chatbot should not list sources.
  const lines = raw.split(/\r?\n/);
  const filtered = [] as string[];
  for (const line of lines) {
    const trimmed = line.trim();
    if (/^sources?:/i.test(trimmed)) continue; // drop 'Sources:' header
    if (/^\[\d+\]/.test(trimmed)) continue; // drop lines starting with [1], [2]
    if (/https?:\/\//.test(trimmed)) continue; // drop raw links
    filtered.push(line);
  }
  return filtered.join('\n').trim();
}

// Main HTTP aiChat handler: routes time-sensitive queries to Facts, otherwise asks the model
export const aiChat = functions
  .region('us-central1')
  .https.onRequest((req, res) => {
    corsHandler(req, res, () => {
      (async () => {
        if (req.method === 'OPTIONS') {
          res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
          res.set('Access-Control-Allow-Headers', 'Content-Type');
          res.status(204).send('');
          return;
        }

        try {
          const userMessage = (req.body?.message ?? req.body?.messages ?? '').toString().slice(0, 4000);
          const imageUrl = (req.body?.image_url || req.body?.imageUrl || '').toString();

          const mode = classifyMode(userMessage);

          // If the user is doing short small talk about identity, return a concise identity answer.
          if (mode === 'small_talk' && /(?:your name|what'?s your name|who are you)\b/i.test(userMessage)) {
            res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
            res.json({ reply: 'Uri, the Uriel Academy study assistant for Ghanaian JHS & SHS students.' });
            return;
          }

          if (mode === 'facts') {
            try {
              const reply = await answerWithFacts(userMessage);
              res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
              res.json({ reply });
              return;
            } catch (e) {
              console.warn('facts call failed, falling back to model', e);
            }
          }

          const system = `
You are **Uri**, a friendly, witty, and highly capable study buddy for students aged 10–21.

## Role

* Help with schoolwork (BECE/WASSCE and beyond), creative writing, life advice, and general chats — like the ChatGPT app, but with a warm Ghanaian vibe.
* Ghana-aware, not Ghana-limited. Use Ghanaian touches naturally (e.g., *chale*, *bro*, *sis*, *no wahala*) without overdoing it.

## Tone

* Conversational, concise, encouraging. Subtle humour, never snark.
* British English by default. Be age-appropriate.
* Treat casual messages as casual (e.g., "thanks" → "You’re welcome, bro! 😊").

## Formatting Rules (IMPORTANT)

* **Default = conversational paragraph(s)**. No auto-headings. No auto numbering.
* Use short lines, light bullets only when it improves readability.
* **Only** use headings/numbered steps/tables/outlines **when the user asks** (e.g., "give steps", "outline", "bulleted", "table", "make a plan", "pros/cons", "SOP").
* For maths or formulas, render cleanly (MathJax/KaTeX), but don't dump LaTeX unless asked.
* If the user says "brief," keep it tight. If they say "full essay," write a well-structured essay.
* End with a supportive nudge when helpful, not every time.

## Behaviour

* Understand intent first; answer directly before adding helpful extras.
* Casual chats allowed (football, music, feelings, ideas, etc.).
* Encourage learning and wellness; keep it safe and respectful.
* Don't define common words or over-explain if the user is just being polite.

## Examples

**User:** thanks
**Uri:** You're welcome, bro! Anytime. 🙌

**User:** I'm tired of studying
**Uri:** I feel you, sis. Take a 5-minute break, stretch, sip water, then let's tackle one small thing together. We got this. 💪

**User:** Explain photosynthesis (short, no bullets)
**Uri:** Photosynthesis is how plants make food using sunlight. Chlorophyll absorbs light, the plant uses carbon dioxide and water, and it produces glucose and oxygen. In short: light in, sugar made, oxygen out.

**User:** Give me a step-by-step plan to revise chemistry
**Uri:**

1. Diagnose topics you're weak in (past questions, 20 mins)
2. Make a 7-day mini-plan...
   *(structured mode only because the user asked for "step-by-step")*

**User:** Write a 900-word essay on climate change causes and solutions (British English)
**Uri:** *[Produces a well-organised essay with intro, body, conclusion — no numbered headings unless requested]*

---

## Optional developer note (lightweight logic)

If you can pass a flag, do this:

* If user message contains words like: *steps, outline, plan, bullets, list, table, SOP, framework, numbered, headings* → **structured_mode = true**
* Else → **structured_mode = false** (conversational paragraphs)

If \`structured_mode=false\`, block auto headings/numbering; allow at most light bullets when it clearly improves readability.

---

`;

          // If an image URL is provided, send a multimodal user content array that includes the image
          const userContent = imageUrl && imageUrl.length > 0
            ? `mode=${'tutoring'}\n\n${userMessage}`
            : `mode=${'tutoring'}\n\n${userMessage}`;

          // Build messages array; include image information as a separate message part if provided
          const modelMessages: any[] = [
            { role: 'system', content: system },
          ];

          if (imageUrl && imageUrl.length > 0) {
            // For models that accept structured multimodal inputs, include image_url as an additional message in the user content
            // The OpenAI client may accept message content as objects; we wrap as a string instructing the model to analyze the image URL
            modelMessages.push({ role: 'user', content: `mode=tutoring\n\nPlease analyze this image: ${imageUrl}\n\n${userMessage}` });
          } else {
            modelMessages.push({ role: 'user', content: userContent });
          }

          const completion = await chatCompletion(modelMessages, 0.3);

          const raw = completion?.choices?.[0]?.message?.content ?? '';
          // return raw (expects KaTeX formatting) so client renders with KaTeX
          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.json({ reply: raw });
        } catch (err: any) {
          console.error('aiChat error:', err);
          try { res.status(500).json({ error: err?.message ?? 'Server error' }); } catch (e) { console.error('Failed to send error response', e); }
        }
      })();
    });
  });

// Facts API: web search + answer with citations using Tavily
export const facts = functions.region('us-central1').https.onRequest((req, res) => {
  corsHandler(req, res, () => {
    (async () => {
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.status(204).send('');
        return;
      }

      try {
        const q = (req.body?.query ?? '').toString().slice(0, 600);
        const tavilyKey = functions.config().tavily?.key;
        if (!tavilyKey) {
          res.status(500).json({ error: 'Facts provider key not configured' });
          return;
        }

        const resp = await fetch('https://api.tavily.com/search', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ api_key: tavilyKey, query: q, max_results: 6, include_answer: true }),
        });
        const data = await resp.json();
        // If Tavily returned a direct answer, prefer it and attach simple citations.
        if (data && data.answer && data.answer.toString().trim().length > 0) {
          const answerText = data.answer.toString();
          const results = (data.results || []);
          // Prefer domain-only citations, no direct links
          const citations = results.slice(0, 3).map((r: any, i: number) => {
            try { const url = new URL(r.url); return `[${i + 1}] ${r.title} — ${url.hostname.replace(/^www\./,'')}`; } catch (e) { return `[${i + 1}] ${r.title}`; }
          }).join('\n');
          const composed = citations ? `${answerText}\n\nSources:\n${citations}` : answerText;
          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.json({ answer: composed });
          return;
        }

        // Fallback: if no direct answer, build a context for the model to summarize
        const context =
          (data?.results ?? []).map((r: any, i: number) => `[${i + 1}] ${r.title} — ${r.url}\n${r.content}`).join('\n\n');

        const ans = await chatCompletion([
          { role: 'system', content: 'Use ONLY the provided context. If something is missing, say you can\'t verify it. Include bracketed citations like [1], [2].' },
          { role: 'user', content: `Question: ${q}\n\nContext:\n${context}` },
        ], 0.1);

        res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
        res.json({ answer: ans.choices?.[0]?.message?.content ?? '' });
      } catch (e: any) {
        console.error('facts error:', e);
        try { res.status(500).json({ error: e?.message ?? 'Server error' }); } catch (ee) { console.error('facts send failed', ee); }
      }
    })();
  });
});

/** Optional: a lightweight health check */
export const ping = functions.region('us-central1').https.onRequest((_, res) => {
  res.status(200).send('pong');
});

// Upload Note: accepts POST with Authorization Bearer <idToken>
// Body: { title?: string, subject?: string, text?: string, imageBase64?: string, fileName?: string }
export const uploadNote = functions.region('us-central1').https.onRequest((req, res) => {
  corsHandler(req, res, () => {
    (async () => {
      if (req.method === 'OPTIONS') { res.set('Access-Control-Allow-Methods', 'POST, OPTIONS'); res.status(204).send(''); return; }
      try {
        // Auth
        const authHeader = req.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Missing Authorization Bearer token' }); return; }
        const idToken = authHeader.split(' ')[1];
        let uid: string | null = null;
        try { const decoded = await admin.auth().verifyIdToken(idToken); uid = decoded.uid; } catch (e) { res.status(401).json({ error: 'Invalid ID token' }); return; }

        const body = req.body || {};
        const title = (body.title || '').toString().slice(0, 300);
        const subject = (body.subject || '').toString().slice(0, 200);
        const text = (body.text || '').toString().slice(0, 20000);
        const imageBase64 = (body.imageBase64 || '').toString();
        const fileName = (body.fileName || '').toString() || `note_${Date.now()}`;

        // Basic input validation
        if (text.isEmpty && imageBase64.isEmpty) { res.status(400).json({ error: 'Empty upload: provide text or image' }); return; }

  // Moderation: require text moderation if text provided
        try {
          if (text && text.length > 0) {
            const mod = await openai.moderations.create({ model: 'omni-moderation-latest', input: text });
            const flagged = (mod as any).results?.[0]?.flagged;
            if (flagged) {
              res.status(403).json({ error: 'Content flagged by moderation' });
              return;
            }
          }
        } catch (e) {
          console.warn('Moderation check failed, continuing with pending status', e instanceof Error ? e.message : e);
        }

        // Decide storage
        const notesRef = admin.firestore().collection('notes').doc();
        const createdAt = admin.firestore.FieldValue.serverTimestamp();
        const docData: any = {
          title: title || fileName,
          subject: subject || null,
          userId: uid,
          createdAt,
          status: 'published', // default
        };

        // If image supplied, upload to storage
        if (imageBase64 && imageBase64.length > 0) {
          try {
            const buffer = Buffer.from(imageBase64, 'base64');
            const extension = fileName.includes('.') ? fileName.split('.').pop() : 'jpg';
            const storagePath = `notes/${uid}/${Date.now()}_${fileName}`;
            const bucket = admin.storage().bucket();
            const file = bucket.file(storagePath);
            // Save the file privately (do NOT make public)
            await file.save(buffer, { contentType: `image/${extension}`, resumable: false });
            // Generate a signed URL for temporary access (7 days)
            let signedUrl: string | null = null;
            try {
              const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
              const [url] = await file.getSignedUrl({ action: 'read', expires });
              signedUrl = url;
            } catch (e) {
              console.warn('Failed to create signed URL for uploaded file', e instanceof Error ? e.message : e);
            }

            // Store storage path and optional signed URL in metadata (file not public)
            docData.filePath = storagePath;
            if (signedUrl) docData.signedUrl = signedUrl;
            docData.fileName = fileName;
            docData.type = 'image';
          } catch (e) {
            console.error('Image upload failed', e instanceof Error ? e.message : e);
            res.status(500).json({ error: 'Failed to upload image' });
            return;
          }
        }

        // If text supplied, store as field
        if (text && text.length > 0) {
          docData.text = text;
          docData.type = docData.type ?? 'text';
        }

        // Write doc
        try {
          await notesRef.set(docData);
        } catch (e) {
          console.error('Failed to save note metadata', e instanceof Error ? e.message : e);
          res.status(500).json({ error: 'Failed to save note' });
          return;
        }

        // Award XP - simple: increment user's xp in Firestore (non-authoritative)
        try {
          const userAggRef = admin.firestore().collection('aggregates').doc('user').collection(uid!).doc('stats');
          await userAggRef.set({ totalNotesUploaded: admin.firestore.FieldValue.increment(1), xp: admin.firestore.FieldValue.increment(150) }, { merge: true });
        } catch (e) {
          console.warn('Failed to award XP', e instanceof Error ? e.message : e);
        }

  res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
  const responseBody: any = { ok: true, noteId: notesRef.id, status: docData.status };
  if (docData.signedUrl) responseBody.signedUrl = docData.signedUrl;
  res.json(responseBody);
        return;
      } catch (err) {
        console.error('uploadNote error', err instanceof Error ? err.stack || err.message : err);
        try { res.status(500).json({ error: 'Internal server error' }); } catch (e) { console.error('Failed to send error response', e); }
        return;
      }
    })();
  });
});

// Generate a fresh signed URL for a note's file. POST { noteId?: string, filePath?: string }
export const getNoteSignedUrl = functions.region('us-central1').https.onRequest((req, res) => {
  corsHandler(req, res, () => {
    (async () => {
      if (req.method === 'OPTIONS') { res.set('Access-Control-Allow-Methods', 'POST, OPTIONS'); res.status(204).send(''); return; }
      try {
        const authHeader = req.get('Authorization') || '';
        if (!authHeader.startsWith('Bearer ')) { res.status(401).json({ error: 'Missing Authorization Bearer token' }); return; }
        const idToken = authHeader.split(' ')[1];
        let uid: string | null = null;
        try { const decoded = await admin.auth().verifyIdToken(idToken); uid = decoded.uid; } catch (e) { res.status(401).json({ error: 'Invalid ID token' }); return; }

        const body = req.body || {};
        const noteId = (body.noteId || '').toString();
        const filePath = (body.filePath || '').toString();

        let storagePath = filePath;
        if (!storagePath && noteId) {
          const doc = await admin.firestore().collection('notes').doc(noteId).get();
          if (!doc.exists) { res.status(404).json({ error: 'Note not found' }); return; }
          const data = doc.data() || {};
          if (data.userId !== uid) { res.status(403).json({ error: 'Not authorized to access this note' }); return; }
          storagePath = data.filePath || '';
        }

        if (!storagePath) { res.status(400).json({ error: 'No filePath or noteId provided' }); return; }

        // Generate signed URL (1 hour)
        try {
          const bucket = admin.storage().bucket();
          const file = bucket.file(storagePath);
          const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
          const [url] = await file.getSignedUrl({ action: 'read', expires });
          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.json({ ok: true, signedUrl: url });
          return;
        } catch (e) {
          console.error('Failed to get signed url', e instanceof Error ? e.message : e);
          res.status(500).json({ error: 'Failed to create signed url' });
          return;
        }
      } catch (e) {
        console.error('getNoteSignedUrl error', e instanceof Error ? e.stack || e.message : e);
        try { res.status(500).json({ error: 'Internal server error' }); } catch (ee) { console.error('Failed to send error', ee); }
        return;
      }
    })();
  });
});

// Callable variant: get signed URL for note. Simpler auth via context.auth
export const getNoteSignedUrlCallable = functions.region('us-central1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  const uid = context.auth.uid;
  const noteId = (data.noteId || '').toString();
  const filePath = (data.filePath || '').toString();

  let storagePath = filePath;
  if (!storagePath && noteId) {
    const doc = await admin.firestore().collection('notes').doc(noteId).get();
    if (!doc.exists) throw new functions.https.HttpsError('not-found', 'Note not found');
    const docData = doc.data() || {};
    if (docData.userId !== uid) throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    storagePath = docData.filePath || '';
  }

  if (!storagePath) throw new functions.https.HttpsError('invalid-argument', 'No filePath or noteId provided');

  try {
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
    const [url] = await file.getSignedUrl({ action: 'read', expires });
    return { ok: true, signedUrl: url };
  } catch (e) {
    console.error('Callable signed url failed', e instanceof Error ? e.message : e);
    throw new functions.https.HttpsError('internal', 'Failed to create signed url');
  }
});

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// Types and interfaces
interface Question {
  id: string;
  subject?: string;
  difficulty?: 'easy' | 'medium' | 'hard';
  year?: number;
  correctAnswer: string;
  explanation?: string;
  topic?: string;
  active?: boolean;
  subjectId?: string;
  // Add other question properties as needed
}

// Utility: set timestamps on write
function timestamps(obj: any) {
  return {
    ...obj,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// Auth Lifecycle Functions
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const userRef = db.collection('users').doc(user.uid);
  const defaultDoc = {
    role: 'student',
    profile: {
      firstName: user.displayName || '',
      email: user.email || '',
      phone: user.phoneNumber || '',
    },
    settings: { 
      language: ['en'], 
      calmMode: false,
      notifications: { email: true, push: true, sms: false }
    },
    badges: { level: 0, points: 0, streak: 0, earned: [] },
    entitlements: [], // Empty by default - requires purchase
    tenant: { schoolId: null }, // Set via school invitation link
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await userRef.set(defaultDoc);
  
  // Create user aggregate document
  await db.collection('aggregates').doc('user').collection(user.uid).doc('stats').set({
    totalAttempts: 0,
    averageScore: 0,
    bestScore: 0,
    streakCurrent: 0,
    streakBest: 0,
    subjectStats: {},
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    ...timestamps({})
  });
});

// Admin function to grant roles and set custom claims
export const grantRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  
  // Only allow super_admins to grant roles
  const caller = await admin.auth().getUser(context.auth.uid);
  const callerClaims = caller.customClaims || {};
  if (callerClaims.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can grant roles');
  }

  const schema = z.object({ 
    uid: z.string(), 
    role: z.enum(['student', 'parent', 'school_admin', 'teacher', 'staff', 'super_admin']), 
    schoolId: z.string().optional(),
    linkedStudentIds: z.array(z.string()).optional() // For parents
  });
  
  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');
  }
  
  const { uid, role, schoolId, linkedStudentIds } = parsed.data;

  const claims: any = { role };
  if (schoolId) claims.schoolId = schoolId;
  if (linkedStudentIds) claims.linkedStudentIds = linkedStudentIds;
  
  await admin.auth().setCustomUserClaims(uid, claims);
  
  // Update user document
  await db.collection('users').doc(uid).update({
    role,
    ...(schoolId && { 'tenant.schoolId': schoolId }),
    ...(linkedStudentIds && { linkedStudentIds }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Log admin action
  await db.collection('audits').add(timestamps({
    action: 'grant_role',
    performedBy: context.auth.uid,
    targetUserId: uid,
    details: { role, schoolId, linkedStudentIds },
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  return { success: true };
});

// Generate Mock Exam
export const generateMockExam = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    subjectId: z.string(),
    difficultyMix: z.object({
      easy: z.number().min(0).max(1),
      medium: z.number().min(0).max(1),
      hard: z.number().min(0).max(1)
    }).optional(),
    questionCount: z.number().min(10).max(100).default(30)
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { subjectId, difficultyMix = { easy: 0.4, medium: 0.4, hard: 0.2 }, questionCount } = parsed.data;

  // Fetch questions by difficulty
  const questionsQuery = await db.collection('pastQuestions')
    .where('subjectId', '==', subjectId)
    .where('active', '==', true)
    .get();

  const questions: Question[] = questionsQuery.docs.map(doc => ({ 
    id: doc.id, 
    ...doc.data() 
  } as Question));
  
  if (questions.length < questionCount) {
    throw new functions.https.HttpsError('failed-precondition', 'Not enough questions available');
  }

  // Shuffle and select questions based on difficulty mix
  const easyQuestions = questions.filter(q => q.difficulty === 'easy');
  const mediumQuestions = questions.filter(q => q.difficulty === 'medium');
  const hardQuestions = questions.filter(q => q.difficulty === 'hard');

  const selectedQuestions = [
    ...easyQuestions.slice(0, Math.floor(questionCount * difficultyMix.easy)),
    ...mediumQuestions.slice(0, Math.floor(questionCount * difficultyMix.medium)),
    ...hardQuestions.slice(0, Math.floor(questionCount * difficultyMix.hard))
  ];

  // Fill remaining slots with any available questions
  const remainingCount = questionCount - selectedQuestions.length;
  const remainingQuestions = questions.filter(q => !selectedQuestions.find(sq => sq.id === q.id));
  selectedQuestions.push(...remainingQuestions.slice(0, remainingCount));

  // Shuffle final selection
  const shuffledQuestions = selectedQuestions.sort(() => Math.random() - 0.5);

  // Create exam document
  const examRef = db.collection('mockExams').doc();
  const examData = {
    subjectId,
    questionIds: shuffledQuestions.map(q => q.id),
    questionCount: shuffledQuestions.length,
    difficultyMix,
    createdBy: context.auth.uid,
    ...timestamps({})
  };

  await examRef.set(examData);

  return {
    examId: examRef.id,
    questionCount: shuffledQuestions.length,
    subject: subjectId
  };
});

// Submit Attempt with server-side scoring
export const submitAttempt = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({ 
    examId: z.string(), 
    answers: z.array(z.object({ 
      qId: z.string(), 
      answer: z.string().nullable() 
    })) 
  });
  
  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { examId, answers } = parsed.data;
  const uid = context.auth.uid;

  // Load mock exam and questions
  const examSnap = await db.collection('mockExams').doc(examId).get();
  if (!examSnap.exists) throw new functions.https.HttpsError('not-found', 'Exam not found');
  
  const exam = examSnap.data()!;
  const questionIds: string[] = exam.questionIds || [];

  // Fetch questions in batch
  const qSnaps = await Promise.all(
    questionIds.map((id: string) => db.collection('pastQuestions').doc(id).get())
  );
  const questions = qSnaps.map(s => s.exists ? (s.data() as any) : null) as Array<any | null>;

  // Server-side scoring using utility
  const result = scoreExam(questions, answers as any);
  const { score, correct, items } = result;

  // Write attempt
  const attemptRef = db.collection('attempts').doc();
  await attemptRef.set(timestamps({ 
    userId: uid, 
    examId, 
    items, 
    score, 
    correct,
    total: answers.length,
    startedAt: admin.firestore.FieldValue.serverTimestamp(), 
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    tenant: { schoolId: context.auth.token.schoolId || null }
  }));

  // Update user aggregates and badges
  const userAggRef = db.collection('aggregates').doc('user').collection(uid).doc('stats');
  const userAgg = await userAggRef.get();
  const currentStats = userAgg.data() || {};
  
  const newStats = {
    totalAttempts: (currentStats.totalAttempts || 0) + 1,
    averageScore: Math.round(((currentStats.averageScore || 0) * (currentStats.totalAttempts || 0) + score) / ((currentStats.totalAttempts || 0) + 1)),
    bestScore: Math.max(currentStats.bestScore || 0, score),
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await userAggRef.set(newStats, { merge: true });

  // Update badges and streaks
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const userData = userDoc.data() || {};
  const badges = userData.badges || { level: 0, points: 0, streak: 0, earned: [] };
  
  badges.points += Math.floor(score / 10); // 10 points per 100% score
  if (score >= 80) {
    badges.streak += 1;
  } else {
    badges.streak = 0;
  }
  
  // Level up logic
  if (badges.points >= (badges.level + 1) * 100) {
    badges.level += 1;
    badges.earned.push(`level_${badges.level}`);
  }

  await userRef.update({
    badges,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return { score, correct, total: answers.length, pointsEarned: Math.floor(score / 10) };
});

// Issue Signed URL for textbooks
export const issueSignedUrl = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  
  const schema = z.object({ bookId: z.string() });
  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');
  
  const { bookId } = parsed.data;
  const uid = context.auth.uid;

  // Check entitlement
  const userDoc = await db.collection('users').doc(uid).get();
  const entitlements = (userDoc.data() || {})['entitlements'] || [];
  
  if (!entitlements.includes('textbooks') && 
      !entitlements.includes('both') && 
      !entitlements.includes('premium') &&
      context.auth.token.role !== 'super_admin' &&
      context.auth.token.role !== 'school_admin') {
    throw new functions.https.HttpsError('permission-denied', 'No entitlement for textbooks');
  }

  // Generate signed URL via storage
  const storage = admin.storage();
  const bucket = storage.bucket();
  const file = bucket.file(`textbooks/${bookId}.pdf`);
  
  try {
    const [url] = await file.getSignedUrl({ 
      action: 'read', 
      expires: Date.now() + 1000 * 60 * 5 // 5 minutes
    });
    
    // Log access for analytics
    await db.collection('auditLogs').add(timestamps({
      action: 'textbook_access',
      userId: uid,
      bookId,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    }));
    
    return { url };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to generate signed URL');
  }
});

// AI Solve Question
export const aiSolveQuestion = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    questionId: z.string(),
    userAnswer: z.string().optional(),
    language: z.enum(['en', 'tw', 'ee', 'ga', 'ha']).default('en')
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { questionId, userAnswer, language } = parsed.data;

  // Rate limiting check (simple implementation)
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData?.entitlements?.includes('premium') && 
      context.auth.token.role !== 'super_admin') {
    // Check daily AI usage limit for non-premium users
    const today = new Date().toISOString().split('T')[0];
    const usageRef = db.collection('aiUsage').doc(`${context.auth.uid}_${today}`);
    const usage = await usageRef.get();
    
    if (usage.exists && (usage.data()?.count || 0) >= 5) {
      throw new functions.https.HttpsError('resource-exhausted', 'Daily AI limit reached');
    }
  }

  // Fetch question
  const questionDoc = await db.collection('pastQuestions').doc(questionId).get();
  if (!questionDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Question not found');
  }

  const questionData = questionDoc.data()!;
  
  // Simple AI response (replace with actual AI service integration)
  const response = {
    explanation: `This is a ${questionData.subject} question about ${questionData.topic}. The correct answer is ${questionData.correctAnswer}.`,
    hints: ['Break down the problem step by step', 'Consider the key concepts involved'],
    correctAnswer: questionData.correctAnswer,
    language
  };

  // Log AI chat
  await db.collection('aiChats').add(timestamps({
    userId: context.auth.uid,
    questionId,
    userAnswer,
    response,
    language,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  // Update usage tracking
  const today = new Date().toISOString().split('T')[0];
  const usageRef = db.collection('aiUsage').doc(`${context.auth.uid}_${today}`);
  await usageRef.set({
    count: admin.firestore.FieldValue.increment(1),
    lastUsed: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  return response;
});

// Verify Entitlement
export const verifyEntitlement = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    requiredEntitlement: z.enum(['past', 'textbooks', 'both', 'premium'])
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { requiredEntitlement } = parsed.data;

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const entitlements: EntitlementType[] = (userDoc.data() || {})['entitlements'] || [];

  const hasAccess = hasEntitlement(entitlements, requiredEntitlement) ||
                    context.auth.token.role === 'super_admin' ||
                    context.auth.token.role === 'school_admin';

  return { hasEntitlement: hasAccess, entitlements };
});

// Flag User for moderation
export const flagUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    flaggedUserId: z.string(),
    reason: z.enum(['inappropriate_content', 'harassment', 'spam', 'cheating', 'other']),
    description: z.string().optional()
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { flaggedUserId, reason, description } = parsed.data;

  await db.collection('adminFlags').add(timestamps({
    flaggedUserId,
    reportedBy: context.auth.uid,
    reason,
    description: description || '',
    status: 'pending',
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  return { success: true };
});

// Scheduled function for weekly reports
export const weeklyReportScheduler = functions.pubsub
  .schedule('0 7 * * 1') // Every Monday at 7 AM
  .timeZone('Africa/Accra')
  .onRun(async (context) => {
    // Get all students and parents
    const usersQuery = await db.collection('users')
      .where('role', 'in', ['student', 'parent'])
      .get();

    const batch = db.batch();
    
    for (const userDoc of usersQuery.docs) {
      const userData = userDoc.data();
      
      if (userData.role === 'student') {
        // Generate student report
        const reportRef = db.collection('reports').doc();
        batch.set(reportRef, timestamps({
          userId: userDoc.id,
          type: 'weekly',
          period: {
            start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
            end: new Date()
          },
          generated: admin.firestore.FieldValue.serverTimestamp()
        }));
      }
    }

    await batch.commit();
    console.log('Weekly reports scheduled for generation');
  });

// Initial setup function - completely open for first admin setup
export const initialSetupAdmin = functions.https.onCall(async (data, context) => {
  try {
    const { email } = data;
    
    // Only allow this for studywithuriel@gmail.com
    if (email !== 'studywithuriel@gmail.com') {
      throw new functions.https.HttpsError('invalid-argument', 'This function is only for initial admin setup');
    }

    console.log('🚀 Initial admin setup for studywithuriel@gmail.com');

    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, { 
      role: 'super_admin',
      email: email 
    });

    // Update user document
    await db.collection('users').doc(userRecord.uid).set({
      role: 'super_admin',
      email: email,
      updatedAt: new Date().toISOString()
    }, { merge: true });

    console.log(`✅ Set super_admin role for ${email}`);
    
    return {
      success: true,
      message: `Successfully set super_admin role for ${email}`,
      uid: userRecord.uid.toString(),
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Error setting admin role:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to set admin role: ${errorMessage}`);
  }
});

// Set Admin Role - One-time setup function
export const setAdminRole = functions.https.onCall(async (data, context) => {
  try {
    const { email } = data;
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }

    // Special case for initial setup - allow setting studywithuriel@gmail.com as admin without auth
    if (email === 'studywithuriel@gmail.com') {
      console.log('Initial admin setup for studywithuriel@gmail.com - bypassing auth check');
    } else {
      // For other emails, require admin authentication
      if (!context.auth || context.auth.token.email !== 'studywithuriel@gmail.com') {
        throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
      }
    }

    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, { 
      role: 'super_admin',
      email: email 
    });

    // Update user document
    await db.collection('users').doc(userRecord.uid).set({
      role: 'super_admin',
      email: email,
      updatedAt: new Date().toISOString()
    }, { merge: true });

    console.log(`Set super_admin role for ${email}`);
    
    return {
      success: true,
      message: `Successfully set super_admin role for ${email}`,
      uid: userRecord.uid.toString(), // Ensure string format
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    console.error('Error setting admin role:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to set admin role: ${errorMessage}`);
  }
});

// Import RME Questions - Web Compatible Version
export const importRMEQuestions = functions.https.onCall(async (data, context) => {
  try {
    // Verify that the user is authenticated and is an admin
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user has admin role in custom claims
    const role = context.auth.token.role as string | undefined;
    const adminEmail = 'studywithuriel@gmail.com';
    
    if (!role || !['admin', 'super_admin'].includes(role)) {
      if (context.auth.token.email !== adminEmail) {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can import questions. Please contact support to get admin access.');
      }
    }

    console.log('Starting RME questions import...');
    
    // RME Questions Data (1999 BECE) - Simplified structure
    const rmeQuestions = [
      { q: "According to Christian teaching, God created man and woman on the", options: ["A. 1st day", "B. 2nd day", "C. 3rd day", "D. 5th day", "E. 6th day"], answer: "E" },
      { q: "Palm Sunday is observed by Christians to remember the", options: ["A. birth and baptism of Christ", "B. resurrection and appearance of Christ", "C. joyful journey of Christ into Jerusalem", "D. baptism of the Holy Spirit", "E. last supper and sacrifice of Christ"], answer: "C" },
      { q: "God gave Noah and his people the rainbow to remember", options: ["A. the floods which destroyed the world", "B. the disobedience of the idol worshippers", "C. that God would not destroy the world with water again", "D. the building of the ark", "E. the usefulness of the heavenly bodies"], answer: "C" },
      { q: "All the religions in Ghana believe in", options: ["A. Jesus Christ", "B. the Bible", "C. the Prophet Muhammed", "D. the Rain god", "E. the Supreme God"], answer: "E" },
      { q: "The Muslim prayers observed between Asr and Isha is", options: ["A. Zuhr", "B. Jumu'ah", "C. Idd", "D. Subhi", "E. Maghrib"], answer: "E" },
      { q: "The Islamic practice where wealthy Muslims cater for the needs of the poor and needy is", options: ["A. Hajj", "B. Zakat", "C. Ibrahr", "D. Mahr", "E. Talaq"], answer: "B" },
      { q: "Prophet Muhammed's twelfth birthday is important because", options: ["A. there was Prophecy about his future", "B. Halimah returned him to his parents", "C. Amina passed away", "D. his father died", "E. Abdul Mutalib died"], answer: "A" },
      { q: "Muslim's last respect to the dead is by", options: ["A. offering Janazah", "B. burial with a coffin", "C. dressing the corpse in suit", "D. sacrificing a ram", "E. keeping the corpse in the mortuary"], answer: "A" },
      { q: "Festivals are celebrated every year in order to", options: ["A. make the people happy", "B. thank the gods for a successful year", "C. adore a new year", "D. punish the wrong doers in the community", "E. initiate the youth into adulthood"], answer: "B" },
      { q: "The burial of pieces of hair, fingernails and toenails of a corpse at his hometown signifies that", options: ["A. there is life after death", "B. the spirit has contact with the living", "C. lesser gods want the spirit", "D. witches are powerful in one's hometown", "E. everyone must be buried in his hometown"], answer: "B" },
      { q: "Mourners from cemetery wash their hands before entering funeral house again to", options: ["A. break relations with the dead", "B. show that they are among the living", "C. announce their return from the cemetery", "D. cleanse themselves from any curse", "E. enable them shake hands with the other mourners"], answer: "D" },
      { q: "Bringing forth children shows that man is", options: ["A. sharing in God's creation", "B. taking God's position", "C. trying to be like God", "D. feeling self-sufficient", "E. controlling God's creation"], answer: "A" },
      { q: "Among the Asante farming is not done on Thursday because", options: ["A. the soil becomes fertile on this day", "B. farmers have to rest on this day", "C. wild animals come out on this day", "D. it is specially reserved for the ancestors", "E. it is the day of the earth goddess"], answer: "E" },
      { q: "Which of the following months is also a special occasion on the Islamic Calendar?", options: ["A. Rajab", "B. Ramadan", "C. Sha'ban", "D. Shawal", "E. Safar"], answer: "B" },
      { q: "The act of going round the Ka'ba seven times during the Hajj teaches", options: ["A. bravery", "B. cleanliness", "C. humility", "D. endurance", "E. honesty"], answer: "C" },
      { q: "It is believed that burying the dead with money helps him to", options: ["A. pay his debtors in the spiritual world", "B. pay for his fare to cross the river to the other world", "C. pay the ancestors for welcoming him", "D. take care of his needs", "E. remove any curse on the living"], answer: "B" },
      { q: "Blessed are the merciful for they shall", options: ["A. see God", "B. obtain mercy", "C. inherit the earth", "D. be called the children of God", "E. be comforted"], answer: "B" },
      { q: "Eid-Ul-Fitr celebration teaches Muslims to", options: ["A. submit to Allah", "B. give alms", "C. sacrifice themselves to God", "D. endure hardship", "E. appreciate God's mercy"], answer: "E" },
      { q: "The rite of throwing stones at the pillars during the Hajj signifies", options: ["A. exercising of the body", "B. victory over the devil", "C. preparing to fight the enemies", "D. security of the holy place", "E. beginning of the pilgrimage"], answer: "B" },
      { q: "The essence of the Muslim fast of Ramadan is to", options: ["A. keep the body fit", "B. save food", "C. make one become used to hunger", "D. guard against evil", "E. honour the poor and needy"], answer: "D" },
      { q: "The animal which is proverbially known to make good use of its time is the", options: ["A. bee", "B. ant", "C. tortoise", "D. hare", "E. serpent"], answer: "B" },
      { q: "People normally save money in order to", options: ["A. use their income wisely", "B. help the government to generate more revenue", "C. be generous to people", "D. prepare for the future", "E. avoid envious friends"], answer: "D" },
      { q: "Which of the following practices may cause sickness?", options: ["A. throwing rubbish anyhow", "B. boiling untreated water", "C. washing fruits before eating", "D. cooking food properly", "E. washing hands before eating"], answer: "A" },
      { q: "One may contract a disease through the following means except", options: ["A. eating contaminated food", "B. drinking polluted water", "C. breathing polluted air", "D. sleeping in a ventilated room", "E. living in overcrowded place"], answer: "D" },
      { q: "The youth can best help in the development of the nation through", options: ["A. politics", "B. education", "C. entertainment", "D. farming", "E. trading"], answer: "B" },
      { q: "One of the aims of youth organization is to protect the youth from", options: ["A. their parents", "B. their teachers", "C. immoral practices", "D. responsible parenthood", "E. peer pressure"], answer: "C" },
      { q: "Youth camps are organized purposely for the youth to", options: ["A. fend for themselves", "B. find their parents", "C. learn to socialize", "D. run away from household chores", "E. form study groups"], answer: "C" },
      { q: "It is a bad habit to use one's leisure time in", options: ["A. reading a story book", "B. telling stories", "C. playing games", "D. gossiping about friends", "E. learning a new skill"], answer: "D" },
      { q: "Hard work is most often crowned with", options: ["A. success", "B. jealousy", "C. hatred", "D. failure", "E. favour"], answer: "A" },
      { q: "One of the child's responsibilities in the home is to", options: ["A. sweep the compound", "B. provide his clothing", "C. pay the school fees", "D. pay the hospital fees", "E. provide his food"], answer: "A" },
      { q: "Which of the following is not the reason for contributing money in the church?", options: ["A. provide school building", "B. building of hospitals", "C. paying the priest", "D. making the elders rich", "E. helping the poor and the needy"], answer: "D" },
      { q: "The traditional saying that 'one finger cannot pick a stone' means", options: ["A. it is easier for people to work together", "B. a crab cannot give birth to a bird", "C. patience is good but hard to practice", "D. poor people have no friends", "E. one should take care of the environment"], answer: "A" },
      { q: "Kente weaving is popular among the", options: ["A. Asante", "B. Kwahu", "C. Fante", "D. Akwapim", "E. Ewe"], answer: "E" },
      { q: "One of the rights of the child is the right", options: ["A. to work on his plot", "B. to education", "C. to sweeping the classroom", "D. to attend school regularly", "E. to obey school rules"], answer: "B" },
      { q: "Which of the following is not taught in religious youth organization?", options: ["A. serving God and nation", "B. leading a disciplined life", "C. loving one's neighbor as one's self", "D. being law abiding", "E. using violence to demand rights"], answer: "E" },
      { q: "Cleanliness is next to", options: ["A. health", "B. wealth", "C. godliness", "D. happiness", "E. success"], answer: "C" },
      { q: "Good citizens have all these qualities except", options: ["A. patriotism", "B. tolerance", "C. honesty", "D. selfishness", "E. obedience"], answer: "D" },
      { q: "Respect for other people's property teaches one to", options: ["A. be liked by all", "B. become wealthy", "C. avoid trouble", "D. be trusted", "E. become popular"], answer: "D" },
      { q: "A stubborn child is one who", options: ["A. does not go to school", "B. plays truancy", "C. does not respect others", "D. does not do his homework", "E. is the one who does not obey his parents"], answer: "E" },
      { q: "The traditional healer does not normally charge high fees because", options: ["A. they are in the subsistence economy", "B. they use cowries for diagnosis", "C. local herbs and plants are used", "D. it will weaken the power of the medicine", "E. of the extended family relationship"], answer: "C" }
    ];
    
    // Get current timestamp as simple number
    const currentTime = Date.now();
    const currentDate = new Date().toISOString();
    
    let importedCount = 0;
    
    // Import each question individually to avoid batch issues
    for (let i = 0; i < rmeQuestions.length; i++) {
      const questionData = rmeQuestions[i];
      
      const questionDoc = {
        id: `rme_1999_q${i + 1}`,
        questionText: questionData.q,
        type: 'multipleChoice',
        subject: 'religiousMoralEducation',
        examType: 'bece',
        year: '1999',
        section: 'A',
        questionNumber: i + 1,
        options: questionData.options,
        correctAnswer: questionData.answer,
        explanation: `This is question ${i + 1} from the 1999 BECE RME exam.`,
        marks: 1,
        difficulty: 'medium',
        topics: ['Religious And Moral Education', 'BECE', '1999'],
        createdAt: currentDate,
        updatedAt: currentDate,
        createdBy: 'system_import',
        isActive: true,
        metadata: {
          source: 'BECE 1999',
          importDate: currentDate,
          verified: true,
          timestamp: currentTime
        }
      };
      
      try {
        await db.collection('questions').doc(questionDoc.id).set(questionDoc);
        importedCount++;
        console.log(`Imported question ${i + 1}: ${questionData.q.substring(0, 50)}...`);
      } catch (error) {
        console.error(`Error importing question ${i + 1}:`, error);
        // Continue with next question instead of failing completely
      }
    }
    
    console.log(`Successfully imported ${importedCount} RME questions to Firestore!`);
    
    // Update metadata with simple values
    try {
      await db.collection('app_metadata').doc('content').set({
        availableYears: ['1999'],
        availableSubjects: ['Religious And Moral Education - RME'],
        lastUpdated: currentDate,
        rmeQuestionsImported: true,
        rmeQuestionsCount: importedCount,
        lastImportTimestamp: currentTime
      }, { merge: true });
      console.log('Updated content metadata');
    } catch (error) {
      console.error('Error updating metadata:', error);
    }
    
    return {
      success: true,
      message: `Successfully imported ${importedCount} RME questions!`,
      questionsImported: importedCount
    };
    
  } catch (error) {
    console.error('Error importing RME questions:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to import RME questions: ${errorMessage}`);
  }
});

// Expose the HTTP wrapper for browsers that need CORS-enabled endpoint
export { aiChatHttp };

// Expose PDF ingestion functions
export const ingestLocalPDFsCallable = ingestLocalPDFs;
export { ingestLocalPDFs };

// Facts API - Production-ready educational content API - VERSION 2
export const factsApi = functions.https.onRequest((req, res) => {
  // Enable CORS for all origins
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  console.log('Facts API called:', { path: req.path, method: req.method });

  // Simple response for now - updated
  res.status(200).json({
    ok: true,
    message: 'Facts API is working! Updated version',
    path: req.path,
    method: req.method,
    timestamp: new Date().toISOString()
  });
});

export default { 
  onUserCreate, 
  grantRole, 
  generateMockExam,
  submitAttempt, 
  issueSignedUrl, 
  aiSolveQuestion,
  verifyEntitlement,
  flagUser,
  weeklyReportScheduler,
  importRMEQuestions,
  setAdminRole,
  initialSetupAdmin
  , aiChatHttp: aiChatHttpSimple, // expose the simple HTTP handler as aiChatHttp for hosting
  ingestDocs,
  ingestPDFs,
  ingestLocalPDFs,
  listPDFs
};