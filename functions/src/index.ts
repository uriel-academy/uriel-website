import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { scoreExam } from './lib/scoring';
import { hasEntitlement, EntitlementType } from './util/entitlement';
import { ingestDocs, ingestPDFs, ingestLocalPDFs, listPDFs } from './ai/ingest';
import { aiChatHttp } from './aiChatHttp';
import OpenAI from 'openai';
import cors from 'cors';

// Note: legacy ai handlers removed. Single consolidated HTTP handler `aiChatHttp` is used.

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

// Track active SSE streams per conversationId to avoid accidental re-broadcasts
const activeSseStreams: Map<string, boolean> = new Map();

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
  if (/(who is|who was|what is|where is|when is|when was|date|schedule|latest|today|update|news|current|now|bece|wassce|president|minister|result|results|2024|2025|2026)\b/.test(s)) return 'facts';
  return 'tutoring';
}

// Robustly extract a plain-text prompt from arbitrary client payloads
function extractPrompt(body: any): string {
  try {
    if (typeof body === 'string') return body as string;
    const candidates = [body?.text, body?.message, body?.prompt, body?.content, body?.input];
    for (const c of candidates) {
      if (typeof c === 'string' && c.trim().length > 0) return c as string;
    }
    // fallback to safe stringify so we don't end up with "[object Object]"
    if (body && typeof body === 'object') return JSON.stringify(body);
  } catch (e) {
    // ignore
  }
  return '';
}

function normalizePrompt(raw: string, maxLen = 4000): string {
  const s = (raw || '').toString().replace(/\s+/g, ' ').trim();
  return s.length > maxLen ? s.slice(0, maxLen) + ' …' : s;
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

// Lightweight Tavily search helper - returns a composed answer or combined results content
async function tavilySearch(query: string, maxResults = 6) {
  try {
    const tavilyKey = functions.config().tavily?.key;
    if (!tavilyKey) return '';
    const resp = await fetch('https://api.tavily.com/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ api_key: tavilyKey, query, max_results: maxResults, include_answer: true }),
    });
    if (!resp.ok) return '';
    const data = await resp.json();
    if (!data) return '';
    // If Tavily returned a direct answer, prefer it.
    if (data.answer && data.answer.toString().trim().length > 0) return data.answer.toString();
    const results = (data.results || []).slice(0, maxResults);
    const composed = results.map((r: any, i: number) => {
      const title = r.title || r.headline || '';
      const url = r.url || '';
      const content = (r.content || r.snippet || '').toString().slice(0, 2000);
      return `[${i + 1}] ${title} — ${url}\n${content}`;
    }).join('\n\n');
    return composed;
  } catch (e) {
    console.warn('tavilySearch failed', e);
    return '';
  }
}

// Main HTTP aiChat handler: routes time-sensitive queries to Facts, otherwise asks the model
export const aiChatHttpLegacy = functions
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
          const rawPrompt = extractPrompt(req.body?.message ?? req.body);
          const userMessage = normalizePrompt(rawPrompt).slice(0, 4000);
          const imageUrl = (req.body?.image_url || req.body?.imageUrl || '').toString();

          // Get sessionId from request or generate new one
          let sessionId = req.body?.sessionId?.toString();
          if (!sessionId) {
            sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
          }

          // Check if this is a user message that needs processing
          const messageRef = admin.firestore().collection('chats').doc(sessionId).collection('messages').doc();
          const messageId = messageRef.id;

          // Save user message to Firestore
          await messageRef.set({
            id: messageId,
            role: 'user',
            text: userMessage,
            imageUrl: imageUrl || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'pending'
          });

          // Check if we should respond (only to user messages with pending status)
          // For now, always respond since this is called directly
          // In the future, this could be triggered by Firestore listeners

          // Mark as processing
          await messageRef.update({ status: 'processing' });

          // Optional auth/session: if client sends Authorization: Bearer <idToken>, load user memory
          const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
          let uid: string | null = null;
          let userProfile: any = null;
          let sessionRef: any = null;
          let sessionDoc: any = null;
          if (authHeader && authHeader.startsWith('Bearer ')) {
            const idToken = authHeader.split(' ')[1];
            try {
              const decoded = await admin.auth().verifyIdToken(idToken);
              uid = decoded.uid;
              // load user profile doc (if exists)
              try {
                const udoc = await admin.firestore().collection('users').doc(uid).get();
                userProfile = udoc.exists ? udoc.data() : null;
              } catch (e) { console.warn('Failed to load user profile', e); }

              // session handling: prefer client-supplied sessionId, else create new
              if (req.body?.sessionId) {
                sessionId = req.body.sessionId.toString();
                sessionRef = admin.firestore().collection('users').doc(uid!).collection('chatSessions').doc(sessionId!);
                const sdoc = await sessionRef.get();
                sessionDoc = sdoc.exists ? sdoc.data() : { summary: '', facts: [], recentMessages: [], turns: 0 };
              } else {
                // create a new session doc
                const newRef = admin.firestore().collection('users').doc(uid!).collection('chatSessions').doc();
                sessionId = newRef.id;
                sessionRef = newRef;
                const now = admin.firestore.FieldValue.serverTimestamp();
                await sessionRef.set({ title: 'Chat session', summary: '', facts: [], openQuestions: [], turns: 0, recentMessages: [], createdAt: now, lastUpdated: now, active: true });
                sessionDoc = { summary: '', facts: [], recentMessages: [], turns: 0 };
              }
            } catch (e) {
              console.warn('aiChat: auth token verify failed, proceeding unauthenticated', e instanceof Error ? e.message : e);
              uid = null;
            }
          }

          // Basic server-side image safety checks: only allow common image mime types and <= 5MB
          async function validateImageUrl(url: string) {
            try {
              // Only allow http(s)
              if (!/^https?:\/\//i.test(url)) return { ok: false, reason: 'Invalid URL' };
              const head = await fetch(url, { method: 'HEAD' });
              if (!head.ok) return { ok: false, reason: `Unable to fetch image: ${head.status}` };
              const contentType = head.headers.get('content-type') || '';
              const contentLength = parseInt(head.headers.get('content-length') || '0', 10) || 0;
              const allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
              if (!allowed.some(a => contentType.toLowerCase().startsWith(a))) {
                return { ok: false, reason: 'Unsupported image type' };
              }
              // Allow images up to 25MB
              if (contentLength > 25 * 1024 * 1024) {
                return { ok: false, reason: 'Image too large' };
              }
              return { ok: true, contentType, contentLength };
            } catch (e) {
              console.warn('validateImageUrl error', e);
              return { ok: false, reason: 'Validation failed' };
            }
          }

          const mode = classifyMode(userMessage);

          // If the user is doing short small talk about identity, return a concise identity answer.
          if (mode === 'small_talk' && /(?:your name|what'?s your name|who are you)\b/i.test(userMessage)) {
            // Save assistant response
            const assistantRef = admin.firestore().collection('chats').doc(sessionId).collection('messages').doc();
            await assistantRef.set({
              id: assistantRef.id,
              role: 'assistant',
              text: 'Uri, the Uriel Academy study assistant for Ghanaian JHS & SHS students.',
              imageUrl: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              status: 'completed'
            });
            // Mark user message as completed
            await messageRef.update({ status: 'completed' });
            res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
            res.json({ reply: 'Uri, the Uriel Academy study assistant for Ghanaian JHS & SHS students.', sessionId });
            return;
          }

          if (mode === 'facts') {
            try {
              const reply = await answerWithFacts(userMessage);
              // Save assistant response
              const assistantRef = admin.firestore().collection('chats').doc(sessionId).collection('messages').doc();
              await assistantRef.set({
                id: assistantRef.id,
                role: 'assistant',
                text: reply,
                imageUrl: null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'completed'
              });
              // Mark user message as completed
              await messageRef.update({ status: 'completed' });
              res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
              res.json({ reply, sessionId });
              return;
            } catch (e) {
              console.warn('facts call failed, falling back to model', e);
            }
          }

          let system = `
You are **Uri**, a friendly, witty, and highly capable study buddy for students aged 10–21.

Knowledge cutoff: June 2025. When in doubt about recent events, prefer using the web search results provided by the server (Tavily) instead of inventing dates or claims.

## Role

* Help with schoolwork (BECE/WASSCE and beyond), creative writing, life advice, and general chats — like the ChatGPT app, but with a warm Ghanaian vibe.
* Ghana-aware, not Ghana-limited. Use Ghanaian touches naturally (e.g., *chale*, *bro*, *sis*, *no wahala*) without overdoing it.

## Tone

* Conversational, concise, encouraging. Subtle humour, never snark.
* British English by default. Be age-appropriate.
* Treat casual messages as casual (e.g., "thanks" → "You’re welcome, bro! 😊").

## Formatting Rules (IMPORTANT)

* **Default = conversational paragraph(s)**. Always break long answers into readable paragraphs — insert a blank line between paragraphs and keep each paragraph to 3–5 sentences when possible.
* Use short lines, light bullets only when it improves readability.
* **Only** use headings/numbered steps/tables/outlines **when the user asks** (e.g., "give steps", "outline", "bulleted", "table", "make a plan", "pros/cons", "SOP").
* For maths or formulas, use LaTeX/KaTeX delimiters ($...$ for inline, $$...$$ for blocks) suitable for MathJax rendering. Use clear Unicode/math symbols and plain-text notation that reads well in a chat when LaTeX is not requested.
* If the user says "brief," keep it tight. If they say "full essay," write a well-structured essay with paragraphs.
* End with a supportive nudge when helpful, not every time.

## Behaviour

* Understand intent first; answer directly before adding helpful extras.
* If a question likely requires up-to-date facts, consult the Tavily web-search context (provided by the server) and cite only the context using bracketed citations when asked.
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
**Uri:** *[Produces a well-organised essay with intro, body, conclusion — with readable paragraphs]*

---

## Optional developer note (lightweight logic)

If you can pass a flag, do this:

* If user message contains words like: *steps, outline, plan, bullets, list, table, SOP, framework, numbered, headings* → **structured_mode = true**
* Else → **structured_mode = false** (conversational paragraphs)

If structured_mode=false, block auto headings/numbering; allow at most light bullets when it clearly improves readability.

---

`;

          // Append compact profile and session info when available to keep mid-term memory
          try {
            if (userProfile) {
              const parts: string[] = [];
              if (userProfile.profile?.firstName) parts.push(`User: ${userProfile.profile.firstName}`);
              if (userProfile.profile?.level) parts.push(`Level: ${userProfile.profile.level}`);
              if (userProfile.goals) parts.push(`Goals: ${JSON.stringify(userProfile.goals)}`);
              if (userProfile.preferences) parts.push(`Preferences: ${JSON.stringify(userProfile.preferences)}`);
              if (parts.length) system += `\n\n## Known user profile & goals\n` + parts.join('\n') + `\n`;
            }
            if (sessionDoc && (sessionDoc.summary || (sessionDoc.facts && sessionDoc.facts.length > 0))) {
              system += `\n\n## Session summary\n${sessionDoc.summary || ''}\n`;
              if (sessionDoc.facts && sessionDoc.facts.length > 0) system += `Known facts: ${JSON.stringify(sessionDoc.facts)}\n`;
            }
          } catch (e) { console.warn('Failed to append profile/session to system prompt', e); }

          // If an image URL is provided, send a multimodal user content array that includes the image
          const userContent = imageUrl && imageUrl.length > 0
            ? `mode=${'tutoring'}\n\n${userMessage}`
            : `mode=${'tutoring'}\n\n${userMessage}`;

          // If image provided, validate it first
          if (imageUrl && imageUrl.length > 0) {
            const v = await validateImageUrl(imageUrl);
            if (!v.ok) {
              await messageRef.update({ status: 'completed' });
              res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
              res.status(400).json({ error: `Invalid image: ${v.reason || 'unknown'}` });
              return;
            }
          }

          // Build messages array; include image information as a separate message part if provided
          const modelMessages: any[] = [
            { role: 'system', content: system },
          ];

          let completion: any = null;
          if (imageUrl && imageUrl.length > 0) {
            // Preferred: structured multimodal message (object) if the SDK/model supports it
            try {
              modelMessages.push({ role: 'user', content: userContent });
              modelMessages.push({ role: 'user', name: 'image', content: JSON.stringify({ type: 'image_url', image_url: imageUrl }) });
              // Ask model with structured object messages
              completion = await chatCompletion(modelMessages, 0.3);
            } catch (e) {
              console.warn('Structured multimodal message failed, falling back to text-inclusion:', e);
              // Fallback: include image URL inline in text
              const fallbackMessages = [
                { role: 'system', content: system },
                { role: 'user', content: `mode=tutoring\n\nPlease analyze this image: ${imageUrl}\n\n${userMessage}` },
              ];
              completion = await chatCompletion(fallbackMessages, 0.3);
            }
          } else {
            completion = await chatCompletion(modelMessages.concat([{ role: 'user', content: userContent }]), 0.3);
          }

          const raw = completion?.choices?.[0]?.message?.content ?? '';

          // Save assistant response to Firestore
          const assistantRef = admin.firestore().collection('chats').doc(sessionId).collection('messages').doc();
          await assistantRef.set({
            id: assistantRef.id,
            role: 'assistant',
            text: raw,
            imageUrl: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'completed'
          });

          // Mark user message as completed
          await messageRef.update({ status: 'completed' });
          // Persist session updates: increment turns, append recentMessages and summarise every 10 turns
          if (uid && sessionRef) {
            try {
              // Update recent messages array (trim to last 50)
              const recent = (sessionDoc?.recentMessages || []).slice(-40);
              recent.push({ ts: Date.now(), user: userMessage.slice(0, 200), reply: (raw || '').toString().slice(0, 600) });
              const newTurns = (sessionDoc?.turns || 0) + 1;
              await sessionRef.update({ recentMessages: recent.slice(-50), turns: newTurns, lastUpdated: admin.firestore.FieldValue.serverTimestamp() });

              // Run small summariser every 10 turns or if no summary yet
              if (!sessionDoc?.summary || newTurns % 10 === 0) {
                const summariserPrompt = [
                  { role: 'system', content: 'You are a tiny summariser. Produce a short dialogue_summary, a list of facts, and open_questions in JSON format {dialogue_summary:string, facts:[string], open_questions:[string]}. Be concise.' },
                  { role: 'user', content: `Recent conversation snippets:\n${recent.slice(-20).map((r: any) => `U: ${r.user}\nA: ${r.reply}`).join('\n\n')}` }
                ];
                try {
                  const summ = await chatCompletion(summariserPrompt, 0.0);
                  const summRaw = summ?.choices?.[0]?.message?.content ?? '';
                  // Attempt to extract JSON blob from summariser output
                  const jsonMatch = summRaw.match(/\{[\s\S]*\}/);
                  if (jsonMatch) {
                    try {
                      const parsed = JSON.parse(jsonMatch[0]);
                      const newSummary = parsed.dialogue_summary || (parsed.summary || '');
                      const newFacts = parsed.facts || [];
                      await sessionRef.update({ summary: newSummary.slice(0, 2000), facts: newFacts.slice(0, 50), lastUpdated: admin.firestore.FieldValue.serverTimestamp() });
                    } catch (e) {
                      await sessionRef.update({ summary: (summRaw || '').toString().slice(0, 2000), lastUpdated: admin.firestore.FieldValue.serverTimestamp() });
                    }
                  } else {
                    // Fallback: store the raw summariser as the summary
                    await sessionRef.update({ summary: (summRaw || '').toString().slice(0, 2000), lastUpdated: admin.firestore.FieldValue.serverTimestamp() });
                  }
                } catch (e) {
                  console.warn('Session summariser failed', e);
                }
              }
            } catch (e) { console.warn('Failed to persist session', e); }
          }

          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.json({ reply: raw, sessionId });
        } catch (err: any) {
          console.error('aiChat error:', err);
          try { res.status(500).json({ error: err?.message ?? 'Server error' }); } catch (e) { console.error('Failed to send error response', e); }
        }
      })();
    });
  });

// Streaming variant: sends incremental text deltas to the client as they arrive
export const aiChatStream = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    try {
      corsHandler(req, res, async () => {
        // Accept POST and GET (GET for EventSource-friendly clients). Handle CORS preflight.
        if (req.method === 'OPTIONS') {
          res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          res.set('Access-Control-Allow-Headers', 'Content-Type');
          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.status(204).send('');
          return;
        }

        if (req.method !== 'POST' && req.method !== 'GET') {
          res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
          return;
        }

        // For GET, accept prompt in query param 'message' or 'prompt'. For POST, use body.
        const rawPrompt = req.method === 'GET'
          ? (req.query?.message || req.query?.prompt || '')
          : extractPrompt(req.body?.message ?? req.body);
        // Coerce query types (ParsedQs) into a safe string
        const rawPromptStr = (typeof rawPrompt === 'string')
          ? rawPrompt
          : Array.isArray(rawPrompt)
            ? rawPrompt.join(' ')
            : String(rawPrompt || '');
        const prompt = normalizePrompt(rawPromptStr).slice(0, 4000);
        if (!prompt) {
          res.status(400).json({ error: 'Empty or invalid message.' });
          return;
        }

        const OPENAI_KEY = functions.config().openai?.key;
        if (!OPENAI_KEY) {
          res.status(500).json({ error: 'OpenAI key not configured on server.' });
          return;
        }

  // Identify conversationId and verify optional auth token to scope streams per-user
        const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
        let uid: string | null = null;
        if (authHeader && authHeader.startsWith('Bearer ')) {
          const idToken = authHeader.split(' ')[1];
          try {
            const decoded = await admin.auth().verifyIdToken(idToken);
            uid = decoded.uid;
          } catch (e) {
            // token verify failed; proceed anonymously but log
            console.warn('aiChatSSE token verify failed', e);
          }
        }

  const conversationId = (req.method === 'GET' ? (req.query?.conversationId as string | undefined) : (req.body?.conversationId as string | undefined)) || uid || `anon_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

  // Optional flags from client
  const useWebSearch = (req.method === 'GET' ? (req.query?.useWebSearch === 'true') : Boolean(req.body?.useWebSearch));

        // Prevent concurrent streams for the same conversation to avoid duplicate/replayed outputs
        if (activeSseStreams.has(conversationId)) {
          res.status(409).json({ error: 'Another active stream exists for this conversation. Close it before opening a new one.' });
          return;
        }
        activeSseStreams.set(conversationId, true);

        // Prepare streaming response headers
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
        res.setHeader('Cache-Control', 'no-cache, no-transform');
        res.setHeader('Connection', 'keep-alive');
        res.flushHeaders?.();

        try {
          // If this is a fact-style query and Tavily is configured, or client requested it, fetch web context
          const mode = classifyMode(prompt);
          let webContext = '';
          try {
            if (mode === 'facts' || useWebSearch) webContext = await tavilySearch(prompt, 6);
          } catch (e) { console.warn('tavilySearch failed for stream', e); }

          // Build system instruction. Respect client request for MathJax/KaTeX if provided.
          // Use the standardized SYSTEM PROMPT tailored for young learners
          const systemStream = `ROLE
You are Uri, a friendly and helpful math tutor for students around 10-11 years old. You explain things clearly, encourage students, and make learning fun.

COMMUNICATION STYLE FOR YOUNG LEARNERS

Text Formatting (CRITICAL):
- Use proper spacing between all sections
- Add blank lines between paragraphs for easy reading
- Use simple headings without ## symbols
- Use clear bullet points with • or numbers (1, 2, 3)
- Never use ** for bold - use plain text instead
- Never use ### for headings - write headings in plain text
- Break up long text into short, digestible chunks

Math Notation:
- {useMathJax} = false by default (age-appropriate)
- Write math using simple symbols: × ÷ + − = 
- Use superscripts naturally: x² x³
- For fractions, write like: 3/4 or "three quarters"
- Show examples with clear spacing
- When showing steps, number them: Step 1, Step 2, etc.

Example of GOOD formatting:

Let's learn about factorization!

What are factors?

Factors are numbers we multiply together to get another number.

For example: 2 × 3 = 6
So 2 and 3 are factors of 6.

Let's try an example:

Find the factors of 12

Step 1: Think of pairs of numbers that multiply to make 12
Step 2: List them out:
  • 1 × 12 = 12
  • 2 × 6 = 12
  • 3 × 4 = 12

Great job! The factors of 12 are: 1, 2, 3, 4, 6, and 12


TONE & LANGUAGE

Use:
- Short sentences (under 20 words when possible)
- Simple, everyday words
- Encouraging phrases like "Great!", "You've got this!", "Let's try..."
- Clear examples for every concept
- Questions to check understanding

Avoid:
- Complex vocabulary without explanation
- Long paragraphs (max 3-4 sentences)
- Technical jargon
- Assuming prior knowledge


WEB SEARCH & VERIFICATION

- If {useWebSearch} is "auto" (default), search only when:
  • Student asks for current information
  • You need to verify a specific fact
  • Topic requires up-to-date data

- Keep verified information simple and cite sources friendly:
  "According to [source name], ..."


PRACTICE & INTERACTION

- Offer practice problems one at a time
- Wait for student response before giving answers
- Give hints before full solutions
- Celebrate effort and progress
- Ask "Would you like to try another one?" or "Does this make sense?"


SAFETY & APPROPRIATENESS

- Keep all content age-appropriate (10-20 years old)
- Use positive, encouraging language
- If a question is inappropriate, gently redirect: "Let's focus on your math learning instead. What topic are you working on?"
- Never share personal information or ask for student's personal details


DEFAULTS
- {useWebSearch} = "auto"
- {useMathJax} = false
- {detailLevel} = "simple" (age-appropriate explanations)
- Always use proper spacing and clear formatting`;

          const inputMessages: any[] = [ { role: 'system', content: systemStream } ];
          if (webContext && webContext.length > 0) inputMessages.push({ role: 'system', content: `WebSearchResults:\n${webContext}` });
          inputMessages.push({ role: 'user', content: prompt });

          const stream = await (openai as any).responses.create({
            model: functions.config().openai?.model || 'gpt-4o-mini',
            input: inputMessages,
            temperature: 0.7,
            max_output_tokens: 900,
            stream: true,
          });

          // Iterate the async stream and write deltas as they arrive. Also accumulate the text to detect low-confidence.
          let accumulated = '';
          for await (const event of stream as any) {
            try {
              if (event.type === 'response.output_text.delta' && event.delta) {
                const d = event.delta.toString();
                accumulated += d;
                res.write(d);
              } else if (event.type === 'response.completed') {
                break;
              }
            } catch (inner) {
              // ignore per-event errors
            }
          }

          // After streaming finishes, detect uncertainty. If present and we did not include webContext, run Tavily and produce an improved answer.
          try {
            const uncertaintyRegex = /\b(I (don'?t|do not) know|I am not sure|I might be wrong|I cannot verify|as of my knowledge cutoff|I may be mistaken|I don'?t have up-to-date)\b/i;
            if (uncertaintyRegex.test(accumulated) && !webContext) {
              // Try to get web context and re-answer
              const fallbackContext = await tavilySearch(prompt, 6);
              if (fallbackContext && fallbackContext.length > 0) {
                // Ask model to produce a concise verified answer using the web context
                const followUpPrompt = [
                  { role: 'system', content: systemStream },
                  { role: 'system', content: `WebSearchResults:\n${fallbackContext}` },
                  { role: 'user', content: `Please provide a concise, verified answer to the question below using ONLY the WebSearchResults above. If something cannot be verified, say so briefly. Question:\n${prompt}` }
                ];
                try {
                  const follow = await chatCompletion(followUpPrompt, 0.0);
                  const followText = follow?.choices?.[0]?.message?.content ?? '';
                  if (followText && followText.length > 0) {
                    // Send an explicit marker that this is a web-verified supplement
                    res.write('\n\n[Web-verified answer]\n');
                    res.write(followText);
                  }
                } catch (e) {
                  console.warn('follow-up re-answer failed', e);
                }
              }
            }
          } catch (e) { console.warn('uncertainty detect failed', e); }

          res.end();
          return;
        } catch (err: any) {
          console.error('aiChatStream inner error:', err?.response?.data || err);
          try { res.write('\n\n[Stream error: ' + (err?.message || 'unexpected') + ']'); } catch (_) {}
          res.end();
          return;
        }
      });
    } catch (err: any) {
      console.error('aiChatStream error:', err);
      try { res.status(500).json({ error: err?.message || 'Unexpected server error.' }); } catch (e) {}
    }
  });

// SSE variant for browsers: text/event-stream with `data:` lines so EventSource can consume
export const aiChatSSE = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    try {
      corsHandler(req, res, async () => {
        if (req.method === 'OPTIONS') {
          res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
          res.set('Access-Control-Allow-Headers', 'Content-Type');
          res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
          res.status(204).send('');
          return;
        }

        // Allow both GET (EventSource-friendly) and POST
        if (req.method !== 'POST' && req.method !== 'GET') {
          res.status(405).json({ error: 'Method not allowed. Use GET or POST.' });
          return;
        }

        // For GET, accept prompt in query param 'message' or 'prompt'. For POST, use body.
        const rawPrompt = req.method === 'GET'
          ? (req.query?.message || req.query?.prompt || '')
          : extractPrompt(req.body?.message ?? req.body);
        // Coerce query types (ParsedQs) into a safe string like we do in aiChatStream
        const rawPromptStr = (typeof rawPrompt === 'string')
          ? rawPrompt
          : Array.isArray(rawPrompt)
            ? rawPrompt.join(' ')
            : String(rawPrompt || '');
        const prompt = normalizePrompt(rawPromptStr).slice(0, 4000);
        if (!prompt) {
          res.status(400).json({ error: 'Empty or invalid message.' });
          return;
        }

        const OPENAI_KEY = functions.config().openai?.key;
        if (!OPENAI_KEY) {
          res.status(500).json({ error: 'OpenAI key not configured on server.' });
          return;
        }

        // Identify conversationId and verify optional auth token to scope streams per-user
        const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
        let uid: string | null = null;
        if (authHeader && authHeader.startsWith('Bearer ')) {
          const idToken = authHeader.split(' ')[1];
          try {
            const decoded = await admin.auth().verifyIdToken(idToken);
            uid = decoded.uid;
          } catch (e) {
            // token verify failed; proceed anonymously but log
            console.warn('aiChatSSE token verify failed', e);
          }
        }

  const conversationId = (req.method === 'GET' ? (req.query?.conversationId as string | undefined) : (req.body?.conversationId as string | undefined)) || uid || `anon_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

  // Optional flags from client
  const useWebSearch = (req.method === 'GET' ? (req.query?.useWebSearch === 'true') : Boolean(req.body?.useWebSearch));

        // Prevent concurrent streams for the same conversation to avoid duplicate/replayed outputs
        if (activeSseStreams.has(conversationId)) {
          res.status(409).json({ error: 'Another active stream exists for this conversation. Close it before opening a new one.' });
          return;
        }
        activeSseStreams.set(conversationId, true);

        // SSE headers
        res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
        res.setHeader('Cache-Control', 'no-cache, no-transform');
        res.setHeader('Connection', 'keep-alive');
        res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
        res.flushHeaders?.();

        try {
          // Call OpenAI and stream responses. Include Tavily web results for fact queries or when client requested.
          const mode = classifyMode(prompt);
          let webContext = '';
          try {
            if (mode === 'facts' || useWebSearch) webContext = await tavilySearch(prompt, 6);
          } catch (e) { console.warn('tavilySearch failed for sse', e); }

          // Use the standardized SYSTEM PROMPT tailored for young learners (SSE variant)
          const systemSse = `ROLE
You are Uri, a friendly and helpful math tutor for students around 10-11 years old. You explain things clearly, encourage students, and make learning fun.

COMMUNICATION STYLE FOR YOUNG LEARNERS

Text Formatting (CRITICAL):
- Use proper spacing between all sections
- Add blank lines between paragraphs for easy reading
- Use simple headings without ## symbols
- Use clear bullet points with • or numbers (1, 2, 3)
- Never use ** for bold - use plain text instead
- Never use ### for headings - write headings in plain text
- Break up long text into short, digestible chunks

Math Notation:
- {useMathJax} = false by default (age-appropriate)
- Write math using simple symbols: × ÷ + − = 
- Use superscripts naturally: x² x³
- For fractions, write like: 3/4 or "three quarters"
- Show examples with clear spacing
- When showing steps, number them: Step 1, Step 2, etc.

Example of GOOD formatting:

Let's learn about factorization!

What are factors?

Factors are numbers we multiply together to get another number.

For example: 2 × 3 = 6
So 2 and 3 are factors of 6.

Let's try an example:

Find the factors of 12

Step 1: Think of pairs of numbers that multiply to make 12
Step 2: List them out:
  • 1 × 12 = 12
  • 2 × 6 = 12
  • 3 × 4 = 12

Great job! The factors of 12 are: 1, 2, 3, 4, 6, and 12


TONE & LANGUAGE

Use:
- Short sentences (under 20 words when possible)
- Simple, everyday words
- Encouraging phrases like "Great!", "You've got this!", "Let's try..."
- Clear examples for every concept
- Questions to check understanding

Avoid:
- Complex vocabulary without explanation
- Long paragraphs (max 3-4 sentences)
- Technical jargon
- Assuming prior knowledge


WEB SEARCH & VERIFICATION

- If {useWebSearch} is "auto" (default), search only when:
  • Student asks for current information
  • You need to verify a specific fact
  • Topic requires up-to-date data

- Keep verified information simple and cite sources friendly:
  "According to [source name], ..."


PRACTICE & INTERACTION

- Offer practice problems one at a time
- Wait for student response before giving answers
- Give hints before full solutions
- Celebrate effort and progress
- Ask "Would you like to try another one?" or "Does this make sense?"


SAFETY & APPROPRIATENESS

- Keep all content age-appropriate (10-20 years old)
- Use positive, encouraging language
- If a question is inappropriate, gently redirect: "Let's focus on your math learning instead. What topic are you working on?"
- Never share personal information or ask for student's personal details


DEFAULTS
- {useWebSearch} = "auto"
- {useMathJax} = false
- {detailLevel} = "simple" (age-appropriate explanations)
- Always use proper spacing and clear formatting`;
          const inputArray: any[] = [ { role: 'system', content: systemSse } ];
          if (webContext && webContext.length > 0) inputArray.push({ role: 'system', content: `WebSearchResults:\n${webContext}` });
          inputArray.push({ role: 'user', content: prompt });

          // Call provider with streaming
          const stream = await (openai as any).responses.create({
            model: functions.config().openai?.model || 'gpt-4o-mini',
            input: inputArray,
            temperature: 0.7,
            max_output_tokens: 900,
            stream: true,
          });

          try {
            // Accumulate streamed text to detect uncertainty
            let acc = '';
            for await (const event of stream as any) {
              try {
                if (event.type === 'response.output_text.delta' && event.delta) {
                  const d = event.delta.toString();
                  acc += d;
                  // Emit SSE data line
                  res.write(`data: ${d}\n\n`);
                } else if (event.type === 'response.completed') {
                  // Send done event
                  res.write('event: done\ndata: {}\n\n');
                  break;
                }
              } catch (inner) { /* ignore per-event errors */ }
            }

            // After stream completes, if the assistant sounded uncertain and we didn't include webContext, fetch web results and send a verified supplement
            try {
              const uncertaintyRegex = /\b(I (don'?t|do not) know|I am not sure|I might be wrong|I cannot verify|as of my knowledge cutoff|I may be mistaken|I don'?t have up-to-date)\b/i;
              if (uncertaintyRegex.test(acc) && !webContext) {
                const fallbackContext = await tavilySearch(prompt, 6);
                if (fallbackContext && fallbackContext.length > 0) {
                  // Ask model to produce a concise verified answer using the web context
                  const followUpPrompt = [
                    { role: 'system', content: systemSse },
                    { role: 'system', content: `WebSearchResults:\n${fallbackContext}` },
                    { role: 'user', content: `Please provide a concise, verified answer to the question below using ONLY the WebSearchResults above. If something cannot be verified, say so briefly. Question:\n${prompt}` }
                  ];
                  try {
                    const follow = await chatCompletion(followUpPrompt, 0.0);
                    const followText = follow?.choices?.[0]?.message?.content ?? '';
                    if (followText && followText.length > 0) {
                      // Emit as a distinct SSE event so clients can handle it
                      res.write(`event: web_verified\ndata: ${JSON.stringify({ answer: followText })}\n\n`);
                    }
                  } catch (e) {
                    console.warn('follow-up re-answer failed (sse)', e);
                  }
                }
              }
            } catch (e) { console.warn('uncertainty detect failed (sse)', e); }
          } finally {
            // Ensure we always clear active stream flag for this conversation
            try { activeSseStreams.delete(conversationId); } catch (_) {}
          }

          res.end();
          return;
        } catch (err: any) {
          console.error('aiChatSSE inner error:', err?.response?.data || err);
          try { res.write(`event: error\ndata: ${JSON.stringify({ message: err?.message || 'unexpected' })}\n\n`); } catch (_) {}
          try { activeSseStreams.delete(conversationId); } catch (_) {}
          res.end();
          return;
        }
      });
    } catch (err: any) {
      console.error('aiChatSSE error:', err);
      try { res.status(500).json({ error: err?.message || 'Unexpected server error.' }); } catch (e) {}
    }
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

// Expose the consolidated HTTP handler
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

// -------------------------
// Recommendation engine
// -------------------------

// Fetch basic user profile (safe - may return null)
async function fetchUserProfile(uid: string) {
  try {
    const doc = await db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  } catch (e) {
    console.warn('fetchUserProfile failed', e);
    return null;
  }
}

// Fetch per-user mastery map. Support both users/{uid}/mastery and top-level mastery collection.
async function fetchMastery(uid: string) {
  try {
    const userMasteryRef = db.collection('users').doc(uid).collection('mastery');
    const snaps = await userMasteryRef.get();
    if (!snaps.empty) {
      const map: any = {};
      snaps.docs.forEach(d => { const dd = d.data(); if (dd.topicId) map[dd.topicId] = dd.score ?? 0; });
      return map;
    }
    // Fallback: top-level 'mastery' collection
    const top = await db.collection('mastery').doc(uid).get();
    if (top.exists) return top.data() || {};
    return {};
  } catch (e) {
    console.warn('fetchMastery failed', e);
    return {};
  }
}

// Fetch recent events (attempts, questions, activity) for recency signals
async function fetchRecentEvents(uid: string, lookback = 90) {
  try {
    const since = Date.now() - lookback * 24 * 60 * 60 * 1000;
    const snaps = await db.collection('events')
      .where('userId', '==', uid)
      .where('createdAt', '>=', new Date(since))
      .orderBy('createdAt', 'desc')
      .limit(200)
      .get();
    return snaps.docs.map(d => d.data());
  } catch (e) {
    console.warn('fetchRecentEvents failed', e);
    return [];
  }
}

// Fetch catalog topics for recommendation candidates. Try common collection names.
async function fetchCatalogTopics(limit = 200) {
  try {
    const colNames = ['topics', 'curriculumTopics', 'catalog_topics'];
    for (const name of colNames) {
      const c = db.collection(name);
      try {
        const snaps = await c.limit(limit).get();
        if (!snaps.empty) return snaps.docs.map(d => ({ id: d.id, ...(d.data() || {}) }));
      } catch (e) {
        // ignore and try next
      }
    }
    // Fallback: sample distinct topic names from pastQuestions
    const pq = await db.collection('pastQuestions').limit(limit).get();
    if (!pq.empty) return pq.docs.map(d => ({ id: d.id, title: (d.data() || {}).topic || (d.data() || {}).subject || 'topic' }));
    return [];
  } catch (e) {
    console.warn('fetchCatalogTopics failed', e);
    return [];
  }
}

// Simple ranking function - returns top N recommendation items
function rankRecommendations(masteryMap: any, catalog: any[], events: any[], limit = 5) {
  // Build recency map for topics based on events
  const recentBoost: any = {};
  for (const ev of events || []) {
    const t = ev.topic || ev.topicId || ev.subject || ev.name;
    if (!t) continue;
    recentBoost[t] = (recentBoost[t] || 0) + 1;
  }

  const scored = (catalog || []).map((c: any) => {
    const tid = c.id || c.topicId || (c.title && c.title.toString().toLowerCase());
    const mastery = (tid && masteryMap[tid]) || (c.defaultMastery ?? 0) || 0; // 0..1
    const importance = (c.importance || 0.5);
    const recency = recentBoost[c.id] ? Math.min(1, recentBoost[c.id] / 5) : 0;
    const score = (1 - mastery) * 0.6 + importance * 0.3 + recency * 0.3;
    return { topicId: tid || c.id, title: c.title || c.name || c.id, score, mastery, importance };
  });

  const sorted = scored.sort((a: any, b: any) => b.score - a.score).slice(0, limit);
  return sorted;
}

// Use AI to create a short human-friendly explanation of the recommendations (optional)
async function explainWithAI(profile: any, items: any[]) {
  try {
    const userSummary = profile ? `User: ${profile.profile?.firstName || ''}, level: ${profile.profile?.level || 'unknown'}` : 'User: anonymous';
    const prompt = [
      { role: 'system', content: 'You are a concise learning recommendations writer. Produce a short paragraph per item explaining why it is recommended and a 1-line actionable next step.' },
      { role: 'user', content: `Profile: ${userSummary}\n\nRecommendations:\n${items.map((i, idx) => `${idx + 1}. ${i.title} (score: ${Math.round((i.score||0)*100)})`).join('\n')}` }
    ];
    const resp = await chatCompletion(prompt, 0.2);
    return resp?.choices?.[0]?.message?.content || '';
  } catch (e) {
    console.warn('explainWithAI failed', e);
    return '';
  }
}

// Write recommendations to Firestore under users/{uid}/recommendations/latest and a history entry
async function writeRecommendations(uid: string, items: any[], aiSummary?: string) {
  try {
    const latestRef = db.collection('users').doc(uid).collection('recommendations').doc('latest');
    await latestRef.set({ items, aiSummary: aiSummary || null, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    const histRef = db.collection('users').doc(uid).collection('recommendationsHistory').doc();
    await histRef.set({ items, aiSummary: aiSummary || null, generatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return true;
  } catch (e) {
    console.warn('writeRecommendations failed', e);
    return false;
  }
}

// Orchestrator for one user
async function processUser(uid: string) {
  try {
    const profile = await fetchUserProfile(uid);
    const mastery = await fetchMastery(uid);
    const events = await fetchRecentEvents(uid, 90);
    const catalog = await fetchCatalogTopics(200);
    const ranked = rankRecommendations(mastery || {}, catalog || [], events || [], 6);
    const aiSummary = await explainWithAI(profile, ranked);
    await writeRecommendations(uid, ranked, aiSummary);
    return { ok: true, count: ranked.length };
  } catch (e) {
    console.error('processUser failed', e);
    return { ok: false };
  }
}

// Helper to list all user IDs (careful on large installs)
async function listUserIds(batchSize = 500) {
  const ids: string[] = [];
  let last: any = null;
  // naive full collection scan - for large installs consider exporting user list
  let q: any = db.collection('users').limit(batchSize);
  while (true) {
    if (last) q = q.startAfter(last);
    const snaps = await q.get();
    if (snaps.empty) break;
    for (const d of snaps.docs) ids.push(d.id);
    last = snaps.docs[snaps.docs.length - 1];
    if (snaps.size < batchSize) break;
  }
  return ids;
}

// Scheduled daily recommendation generator
export const recommendationsDaily = functions.pubsub
  .schedule('30 6 * * *') // Every day at 06:30
  .timeZone('Africa/Accra')
  .onRun(async (context) => {
    console.log('recommendationsDaily: starting run');
    try {
      const uids = await listUserIds(200);
      for (const uid of uids) {
        try { await processUser(uid); } catch (e) { console.warn('recommendationsDaily processUser failed for', uid, e); }
      }
      console.log('recommendationsDaily: completed');
    } catch (e) {
      console.error('recommendationsDaily failed', e);
    }
  });

// On-demand callable function to run for a particular user (admin or self)
export const recommendationsRunNow = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  const targetUid = (data?.uid && typeof data.uid === 'string') ? data.uid : context.auth.uid;
  // Only allow others if caller is admin
  if (targetUid !== context.auth.uid) {
    const caller = await admin.auth().getUser(context.auth.uid);
    const claims = caller.customClaims || {};
    if (!claims || !['super_admin', 'school_admin', 'admin'].includes(claims.role || '')) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized to generate for other users');
    }
  }

  const r = await processUser(targetUid);
  if (!r.ok) throw new functions.https.HttpsError('internal', 'Failed to generate recommendations');
  return { ok: true, count: r.count };
});

// End recommendation engine

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
  initialSetupAdmin,
  recommendationsDaily,
  recommendationsRunNow,
  aiChatHttp: aiChatHttp, // expose the consolidated HTTP handler for hosting
  ingestDocs,
  ingestPDFs,
  ingestLocalPDFs,
  listPDFs
};