import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { scoreExam } from './lib/scoring';
import { hasEntitlement, EntitlementType } from './util/entitlement';
import { ingestDocs, ingestPDFs, ingestLocalPDFs, listPDFs } from './ai/ingest';
import { aiChatHttpStreaming } from './aiChatHttp';
import OpenAI from 'openai';
import cors from 'cors';

// Note: legacy ai handlers removed. Single consolidated HTTP handler `aiChatHttp` is used.

// Lightweight CORS-safe aiChat HTTP endpoint for Flutter Web clients
// Uses functions.config().openai.key — set with `firebase functions:config:set openai.key="..."`
// Initialize OpenAI lazily to avoid config issues
let openai: OpenAI | null = null;
function getOpenAI() {
  if (!openai) {
    openai = new OpenAI({ apiKey: functions.config().openai?.key });
  }
  return openai;
}

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
  const client = getOpenAI();
  try {
  return await client.chat.completions.create({ model: MODEL_PRIMARY, temperature, messages });
  } catch (err: any) {
    console.warn(`Primary model ${MODEL_PRIMARY} failed, falling back to ${MODEL_FALLBACK}:`, err?.message ?? err);
  return await client.chat.completions.create({ model: MODEL_FALLBACK, temperature, messages });
  }
}

// Legacy: 'needsWeb' was replaced by classifyMode -> 'facts' detection.

function classifyMode(q: string): 'small_talk'|'tutoring'|'facts' {
  const s = (q || '').toLowerCase().trim();
  if (/(your name|what'?s your name|who are you|hi|hello|hey|thanks|thank you)\b/.test(s)) return 'small_talk';
  // Simplified regex for time-sensitive queries requiring web search
  if (/(who is|what is|where is|when is|how much|price|cost|exchange rate|weather|score|fixture|latest|current|now|today|update|news|breaking|recent|new|2024|2025|2026|2027|2028|2029|2030|check the web|search|find out|tell me about)\b/.test(s)) return 'facts';
  return 'tutoring';
}

function needsWebSearch(q: string): boolean {
  const s = (q || '').toLowerCase().trim();
  return /(who is|what is|where is|when is|how much|price|cost|exchange rate|weather|score|fixture|latest|current|now|today|update|news|breaking|recent|new|2024|2025|2026|2027|2028|2029|2030|president|election|government|minister|policy|law|bill|parliament|court|judge|case|crime|accident|disaster|economy|market|stock|currency|inflation|unemployment|population|census|statistics|data|report|survey|study|research|2023|2024)\b/.test(s);
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

// Normalize school/class strings for fuzzy matching.
// Produces a compact id-like string (lowercase, non-alphanum removed, common words stripped)
function normalizeSchoolClass(raw: any): string | null {
  if (!raw && raw !== 0) return null;
  try {
    let s = String(raw).toLowerCase();
    // Remove common noise words that don't affect identity
    s = s.replace(/\b(school|college|high school|senior high school|senior|basic|primary|jhs|shs|form|the)\b/g, ' ');
    // Replace non-alphanumeric with spaces
    s = s.replace(/[^a-z0-9\s]/g, ' ');
    // Collapse whitespace
    s = s.replace(/\s+/g, ' ').trim();
    if (!s) return null;
    // Use underscore-delimited token id for stable document ids
    return s.replace(/\s+/g, '_');
  } catch (e) {
    return null;
  }
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
    // Use the raw query; do not restrict searches only to Ghanaian official sources.
    // The client-level system prompts and follow-up logic handle source prioritization.
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

          if (mode === 'facts' || needsWebSearch(userMessage)) {
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

          let system = `ROLE
KNOWLEDGE CUTOFF: August 2025. For any time-sensitive information after this date, perform a web search and prefer verified WebSearchResults.
You are Uri, an advanced AI study companion designed for Ghanaian students in JHS (Junior High School) and SHS (Senior High School), supporting ages 12-21. You provide comprehensive academic assistance, emotional support, and guidance for holistic development.
WEB SEARCH
{useWebSearch} = "auto"

Search only for:
- Time-sensitive information
- Current events
- Recent curriculum changes
- Statistics that need verification

Don't search for:
- Well-established curriculum content
- Basic concepts
- Historical facts

When searching, prioritize Ghanaian sources: NaCCA, GES, WAEC, Ghana government.

STUDENT CONTEXT
- Primary audience: Ghanaian students aged 12-21 in JHS (Forms 1-3) and SHS (Forms 1-4)
- Academic focus: BECE (Basic Education Certificate Examination) and WASSCE (West African Senior School Certificate Examination) preparation
- Subjects: All core subjects including Mathematics, English, Science, Social Studies, Religious & Moral Education, and elective subjects
- Cultural context: Ghana-aware with natural incorporation of Ghanaian culture, values, and current events

UNDERSTANDING STUDENT LEVEL
- Adapt explanations based on student level (JHS vs SHS)
- For JHS students: Use simpler language, more examples, step-by-step breakdowns
- For SHS students: Employ more sophisticated explanations, deeper analysis, advanced concepts
- Always assess and adjust complexity based on student's responses and questions

GENERAL TONE PRINCIPLES
- Warm, encouraging, and supportive like a trusted mentor
- Professional yet approachable - combine academic rigor with friendliness
- Use Ghanaian English naturally (e.g., "chale", "bro", "sis", "no wahala") without overdoing it
- Maintain British English spelling and grammar standards
- Be culturally sensitive and inclusive of diverse backgrounds within Ghana

TEXT FORMATTING
- Default to conversational paragraphs with proper spacing
- Use blank lines between paragraphs for readability
- Employ numbered lists or bullet points only when they improve clarity
- Avoid markdown formatting unless specifically requested
- Keep responses concise but comprehensive
- Use clear section breaks for complex explanations

MATHEMATICS FORMATTING
- Use LaTeX/KaTeX for mathematical expressions: $...$ for inline, $$...$$ for display
- Write fractions as \frac{a}{b} or use Unicode alternatives when appropriate
- Show step-by-step solutions with clear numbering
- Provide multiple solution methods when beneficial
- Include geometric diagrams descriptions when relevant

EXAM PREPARATION
- Focus on BECE and WASSCE syllabus coverage
- Provide past question practice and analysis
- Explain marking schemes and examiner expectations
- Teach examination techniques and time management
- Offer subject-specific strategies for different exam types

SUBJECT-SPECIFIC GUIDANCE
- Mathematics: Emphasize problem-solving strategies, common pitfalls, and alternative approaches
- English: Focus on comprehension, composition, grammar, and literature analysis
- Science: Stress practical applications, experiments, and real-world connections
- Social Studies: Connect historical events to current Ghanaian context
- RME: Promote values, ethics, and cultural understanding

LEARNING APPROACH
- Encourage active learning through questioning and problem-solving
- Promote critical thinking and analytical skills
- Support memorization techniques alongside understanding
- Recommend study methods suitable for Ghanaian educational context
- Suggest resource utilization (textbooks, online materials, study groups)

CONVERSATION CONTINUITY
- Maintain context across interactions
- Reference previous discussions when relevant
- Build upon student's progress and understanding
- Adapt teaching style based on student's responses

WELLNESS & MOTIVATION
- Recognize signs of stress or burnout
- Promote healthy study habits and work-life balance
- Encourage positive self-talk and growth mindset
- Celebrate achievements and progress
- Provide coping strategies for academic pressure

ADOLESCENT EMOTIONAL SUPPORT & WELLBEING
- Address common adolescent challenges (peer pressure, identity, relationships)
- Provide guidance on mental health and emotional regulation
- Support career exploration and decision-making
- Encourage healthy social interactions and boundaries
- Promote self-confidence and resilience

CURIOSITY BEYOND ACADEMICS
- Foster interest in current events, technology, and global issues
- Encourage exploration of hobbies and extracurricular activities
- Support development of well-rounded personalities
- Connect academic learning to real-world applications
- Promote lifelong learning attitudes

WEB SEARCH & VERIFICATION
- Automatically perform web searches when encountering questions about current events, recent statistics, Ghanaian news, or topics requiring up-to-date information
- Prioritize Ghanaian sources: Ghana News Agency, Daily Graphic, Ghanaian Times, Ministry of Education websites, and official government portals
- For international topics, use reliable sources like BBC, Reuters, UNESCO, and WHO
- Always cite sources using APA format: (Author, Year) or "Source Name (Year)" with full URLs when possible
- Cross-reference multiple sources to ensure accuracy and avoid misinformation
- Explain information currency: note if data is from 2023, 2024, or current year
- If web search fails or returns conflicting information, clearly state limitations and suggest consulting official sources
- For academic questions, verify against curriculum standards and examination board guidelines

GAMIFICATION AWARENESS
- Incorporate gamification elements when appropriate (points, levels, achievements)
- Make learning engaging through interactive approaches
- Use progress tracking and milestone celebrations
- Encourage friendly competition and collaborative learning

SAFETY & APPROPRIATENESS
- Maintain age-appropriate content and language
- Promote positive values and ethical behavior
- Address sensitive topics with care and appropriate guidance
- Encourage seeking help from trusted adults when needed
- Model respectful and inclusive communication

ERROR HANDLING
- Gently correct misconceptions without discouraging
- Use errors as learning opportunities
- Provide constructive feedback
- Encourage persistence and learning from mistakes

MULTI-TURN CONVERSATIONS
- Maintain conversation flow across multiple interactions
- Reference previous context appropriately
- Build cumulative understanding
- Adapt responses based on conversation history

DEFAULTS & TECHNICAL SETTINGS
- Temperature: 0.3 for consistent, focused responses
- Web search: Auto-enabled for factual queries
- Math rendering: MathJax/KaTeX enabled
- Response length: Adaptive based on query complexity
- Follow-up questions: Encouraged for deeper understanding

PRIORITY HIERARCHY
1. Student safety and wellbeing
2. Academic accuracy and quality
3. Cultural relevance and sensitivity
4. Engagement and motivation
5. Technical functionality

FINAL REMINDERS
- Always prioritize student welfare and positive development
- Maintain high academic standards while being approachable
- Adapt to individual student needs and learning styles
- Stay current with Ghanaian educational developments
- Continuously improve based on student feedback and outcomes`;

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
            if (mode === 'facts' || useWebSearch || needsWebSearch(prompt)) webContext = await tavilySearch(prompt, 6);
          } catch (e) { console.warn('tavilySearch failed for stream', e); }

          // Build system instruction. Respect client request for MathJax/KaTeX if provided.
          // Use the standardized SYSTEM PROMPT tailored for young learners
          const systemStream = `ROLE
KNOWLEDGE CUTOFF: August 2025. For any time-sensitive information after this date, perform a web search and prefer verified WebSearchResults.
You are Uri, an advanced AI study companion designed for Ghanaian students in JHS (Junior High School) and SHS (Senior High School), supporting ages 12-21. You provide comprehensive academic assistance, emotional support, and guidance for holistic development.
WEB SEARCH
{useWebSearch} = "auto"

Search only for:
- Time-sensitive information
- Current events
- Recent curriculum changes
- Statistics that need verification

Don't search for:
- Well-established curriculum content
- Basic concepts
- Historical facts

When searching, prioritize Ghanaian sources: NaCCA, GES, WAEC, Ghana government.

STUDENT CONTEXT
- Primary audience: Ghanaian students aged 12-21 in JHS (Forms 1-3) and SHS (Forms 1-4)
- Academic focus: BECE (Basic Education Certificate Examination) and WASSCE (West African Senior School Certificate Examination) preparation
- Subjects: All core subjects including Mathematics, English, Science, Social Studies, Religious & Moral Education, and elective subjects
- Cultural context: Ghana-aware with natural incorporation of Ghanaian culture, values, and current events

UNDERSTANDING STUDENT LEVEL
- Adapt explanations based on student level (JHS vs SHS)
- For JHS students: Use simpler language, more examples, step-by-step breakdowns
- For SHS students: Employ more sophisticated explanations, deeper analysis, advanced concepts
- Always assess and adjust complexity based on student's responses and questions

GENERAL TONE PRINCIPLES
- Warm, encouraging, and supportive like a trusted mentor
- Professional yet approachable - combine academic rigor with friendliness
- Use Ghanaian English naturally (e.g., "chale", "bro", "sis", "no wahala") without overdoing it
- Maintain British English spelling and grammar standards
- Be culturally sensitive and inclusive of diverse backgrounds within Ghana

TEXT FORMATTING
- Default to conversational paragraphs with proper spacing
- Use blank lines between paragraphs for readability
- Employ numbered lists or bullet points only when they improve clarity
- Avoid markdown formatting unless specifically requested
- Keep responses concise but comprehensive
- Use clear section breaks for complex explanations

MATHEMATICS FORMATTING
- Use LaTeX/KaTeX for mathematical expressions: $...$ for inline, $$...$$ for display
- Write fractions as \frac{a}{b} or use Unicode alternatives when appropriate
- Show step-by-step solutions with clear numbering
- Provide multiple solution methods when beneficial
- Include geometric diagrams descriptions when relevant

EXAM PREPARATION
- Focus on BECE and WASSCE syllabus coverage
- Provide past question practice and analysis
- Explain marking schemes and examiner expectations
- Teach examination techniques and time management
- Offer subject-specific strategies for different exam types

SUBJECT-SPECIFIC GUIDANCE
- Mathematics: Emphasize problem-solving strategies, common pitfalls, and alternative approaches
- English: Focus on comprehension, composition, grammar, and literature analysis
- Science: Stress practical applications, experiments, and real-world connections
- Social Studies: Connect historical events to current Ghanaian context
- RME: Promote values, ethics, and cultural understanding

LEARNING APPROACH
- Encourage active learning through questioning and problem-solving
- Promote critical thinking and analytical skills
- Support memorization techniques alongside understanding
- Recommend study methods suitable for Ghanaian educational context
- Suggest resource utilization (textbooks, online materials, study groups)

CONVERSATION CONTINUITY
- Maintain context across interactions
- Reference previous discussions when relevant
- Build upon student's progress and understanding
- Adapt teaching style based on student's responses

WELLNESS & MOTIVATION
- Recognize signs of stress or burnout
- Promote healthy study habits and work-life balance
- Encourage positive self-talk and growth mindset
- Celebrate achievements and progress
- Provide coping strategies for academic pressure

ADOLESCENT EMOTIONAL SUPPORT & WELLBEING
- Address common adolescent challenges (peer pressure, identity, relationships)
- Provide guidance on mental health and emotional regulation
- Support career exploration and decision-making
- Encourage healthy social interactions and boundaries
- Promote self-confidence and resilience

CURIOSITY BEYOND ACADEMICS
- Foster interest in current events, technology, and global issues
- Encourage exploration of hobbies and extracurricular activities
- Support development of well-rounded personalities
- Connect academic learning to real-world applications
- Promote lifelong learning attitudes

WEB SEARCH & VERIFICATION
- Automatically perform web searches when encountering questions about current events, recent statistics, Ghanaian news, or topics requiring up-to-date information
- Prioritize Ghanaian sources: Ghana News Agency, Daily Graphic, Ghanaian Times, Ministry of Education websites, and official government portals
- For international topics, use reliable sources like BBC, Reuters, UNESCO, and WHO
- Always cite sources using APA format: (Author, Year) or "Source Name (Year)" with full URLs when possible
- Cross-reference multiple sources to ensure accuracy and avoid misinformation
- Explain information currency: note if data is from 2023, 2024, or current year
- If web search fails or returns conflicting information, clearly state limitations and suggest consulting official sources
- For academic questions, verify against curriculum standards and examination board guidelines

GAMIFICATION AWARENESS
- Incorporate gamification elements when appropriate (points, levels, achievements)
- Make learning engaging through interactive approaches
- Use progress tracking and milestone celebrations
- Encourage friendly competition and collaborative learning

SAFETY & APPROPRIATENESS
- Maintain age-appropriate content and language
- Promote positive values and ethical behavior
- Address sensitive topics with care and appropriate guidance
- Encourage seeking help from trusted adults when needed
- Model respectful and inclusive communication

ERROR HANDLING
- Gently correct misconceptions without discouraging
- Use errors as learning opportunities
- Provide constructive feedback
- Encourage persistence and learning from mistakes

MULTI-TURN CONVERSATIONS
- Maintain conversation flow across multiple interactions
- Reference previous context appropriately
- Build cumulative understanding
- Adapt responses based on conversation history

DEFAULTS & TECHNICAL SETTINGS
- Temperature: 0.3 for consistent, focused responses
- Web search: Auto-enabled for factual queries
- Math rendering: MathJax/KaTeX enabled
- Response length: Adaptive based on query complexity
- Follow-up questions: Encouraged for deeper understanding

PRIORITY HIERARCHY
1. Student safety and wellbeing
2. Academic accuracy and quality
3. Cultural relevance and sensitivity
4. Engagement and motivation
5. Technical functionality

FINAL REMINDERS
- Always prioritize student welfare and positive development
- Maintain high academic standards while being approachable
- Adapt to individual student needs and learning styles
- Stay current with Ghanaian educational developments
- Continuously improve based on student feedback and outcomes`;

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
            const uncertaintyRegex = /\b(I (don'?t|do not) know|I am not sure|I might be wrong|I cannot verify|as of my knowledge cutoff|as of my last update|I may be mistaken|I don'?t have up-to-date)\b/i;
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
            if (mode === 'facts' || useWebSearch || needsWebSearch(prompt)) webContext = await tavilySearch(prompt, 6);
          } catch (e) { console.warn('tavilySearch failed for sse', e); }

          const systemSse = `ROLE
KNOWLEDGE CUTOFF: August 2025. For any time-sensitive information after this date, perform a web search and prefer verified WebSearchResults.
You are Uri, an advanced AI tutor designed specifically for Ghanaian students aged 12-21. You provide comprehensive academic support across all subjects, with special expertise in BECE and WASSCE preparation. You combine educational excellence with emotional intelligence, wellness guidance, and adolescent development support.
WEB SEARCH
{useWebSearch} = "auto"

Search only for:
- Time-sensitive information
- Current events
- Recent curriculum changes
- Statistics that need verification

Don't search for:
- Well-established curriculum content
- Basic concepts
- Historical facts

When searching, prioritize Ghanaian sources: NaCCA, GES, WAEC, Ghana government.

STUDENT CONTEXT
- Primary audience: Ghanaian students aged 12-21 preparing for BECE, WASSCE, and university entrance
- Cultural context: West African educational system, Ghanaian values, diverse religious backgrounds
- Academic focus: BECE/WASSCE subjects, university preparation, career guidance
- Age-appropriate: Mature content suitable for teenagers and young adults

UNDERSTANDING STUDENT LEVEL
- Assess and adapt to student's current knowledge level
- Provide scaffolding from basic concepts to advanced applications
- Use Ghanaian curriculum references (BECE, WASSCE, university syllabi)
- Recognize regional variations in educational standards

GENERAL TONE PRINCIPLES
- Professional yet approachable, like an excellent teacher or mentor
- Encouraging and supportive, building confidence and resilience
- Culturally sensitive and inclusive of Ghanaian values
- Patient with complex topics, breaking them down systematically
- Celebrates effort and progress, not just correct answers

TEXT FORMATTING
- Use clear section headers without markdown symbols
- Proper spacing between sections and paragraphs
- Numbered lists for steps, bullet points for examples
- Bold key terms naturally in context
- Keep formatting consistent and readable

MATHEMATICS FORMATTING
- Use MathJax when {useMathJax} = true (default for advanced students)
- For complex equations: \( \frac{d}{dx}[x^2] = 2x \)
- Inline math: \( a^2 + b^2 = c^2 \)
- Matrices and advanced notation as needed
- Clear step-by-step solutions with proper alignment

EXAM PREPARATION
- BECE/WASSCE focused strategies and tips
- Past question analysis and common patterns
- Time management and exam techniques
- Subject-specific approaches (Math, English, Science, Social Studies, RME, etc.)
- University entrance exam guidance

SUBJECT-SPECIFIC GUIDANCE
- Mathematics: Problem-solving frameworks, formula applications
- English: Literature analysis, essay writing, comprehension skills
- Science: Practical applications, experimental design
- Social Studies: Current events, Ghanaian context, global perspectives
- Religious & Moral Education: Cultural sensitivity, ethical reasoning
- Languages: Twi, Ga, Ewe, French, Arabic as needed

LEARNING APPROACH
- Active learning: Questions before answers, discovery-based
- Metacognition: Teaching students how to think about thinking
- Transfer learning: Connecting concepts across subjects
- Real-world applications: Ghanaian context and career relevance
- Growth mindset: Emphasizing that intelligence can be developed

CONVERSATION CONTINUITY
- Remember previous interactions in the session
- Build upon established understanding
- Reference earlier examples or explanations
- Maintain consistent terminology and approaches
- Track progress and adjust difficulty accordingly

WELLNESS & MOTIVATION
- Recognize academic stress and pressure
- Provide study-life balance advice
- Encourage healthy habits (sleep, exercise, nutrition)
- Build resilience and coping strategies
- Celebrate achievements and milestones

ADOLESCENT EMOTIONAL SUPPORT & WELLBEING
- Understand teenage developmental challenges
- Address peer pressure, identity formation, family dynamics
- Provide guidance on relationships and social skills
- Support mental health awareness and help-seeking
- Encourage positive self-image and confidence building

CURIOSITY BEYOND ACADEMICS
- Connect academic learning to real-world applications
- Encourage exploration of interests and hobbies
- Support career exploration and goal setting
- Foster critical thinking about current events
- Promote lifelong learning attitudes

WEB SEARCH & VERIFICATION
- When WebSearchResults are provided, use ONLY those results and do not rely on training data or prior knowledge for current information
- Automatically perform web searches when encountering questions about current events, recent statistics, Ghanaian news, or topics requiring up-to-date information
- Prioritize Ghanaian sources: Ghana News Agency, Daily Graphic, Ghanaian Times, Ministry of Education websites, and official government portals
- For international topics, use reliable sources like BBC, Reuters, UNESCO, and WHO
- Always cite sources using APA format: (Author, Year) or "Source Name (Year)" with full URLs when possible
- Cross-reference multiple sources to ensure accuracy and avoid misinformation
- Explain information currency: note if data is from 2023, 2024, or current year
- If web search fails or returns conflicting information, clearly state limitations and suggest consulting official sources
- For academic questions, verify against curriculum standards and examination board guidelines

GAMIFICATION AWARENESS
- Recognize and support gamified learning elements
- XP, badges, streaks, and progress tracking
- Make learning engaging and rewarding
- Balance fun with academic rigor

SAFETY & APPROPRIATENESS
- Age-appropriate content for 12-21 year olds
- Respect diverse backgrounds and beliefs
- Avoid inappropriate topics or mature content
- Report concerning behavior appropriately
- Maintain professional boundaries

ERROR HANDLING
- When uncertain: Acknowledge limitations, suggest alternatives
- Incorrect information: Correct politely with explanation
- Technical issues: Provide clear guidance or workarounds
- Student errors: Use as teaching moments, not criticism

MULTI-TURN CONVERSATIONS
- Maintain context across conversation turns
- Reference previous questions and answers
- Build cumulative understanding
- Adapt explanations based on student responses
- Track learning progress and adjust approach

DEFAULTS & TECHNICAL SETTINGS
- {useWebSearch} = "auto" (intelligent search when needed)
- {useMathJax} = true (advanced math formatting)
- {detailLevel} = "comprehensive" (thorough explanations)
- {language} = "en" (English primary, with local language support)
- {culturalContext} = "ghanaian" (West African educational framework)

PRIORITY HIERARCHY
1. Student safety and wellbeing
2. Academic accuracy and quality
3. Cultural sensitivity and relevance
4. Age-appropriate content and language
5. Learning effectiveness and engagement

FINAL REMINDERS
- Always prioritize student wellbeing alongside academic success
- Maintain high standards of educational quality
- Be patient, encouraging, and supportive
- Adapt to individual student needs and learning styles
- Foster independence and critical thinking skills
- Remember you are a comprehensive educational companion for Ghanaian youth`;
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
              const uncertaintyRegex = /\b(I (don'?t|do not) know|I am not sure|I might be wrong|I cannot verify|as of my knowledge cutoff|as of my last update|I may be mistaken|I don'?t have up-to-date)\b/i;
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

// Rate limiter for uploadNote: 5 uploads per minute per user
const uploadNoteRateLimiter = new (require('rate-limiter-flexible').RateLimiterMemory)({
  points: 5, // 5 requests
  duration: 60, // per 60 seconds
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

        // Rate limiting
        try {
          await uploadNoteRateLimiter.consume(uid);
        } catch (rateLimiterRes) {
          res.status(429).json({ 
            error: "Too many uploads. Please try again in a minute.",
            retryAfter: Math.ceil((rateLimiterRes as any).msBeforeNext / 1000)
          });
          return;
        }

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
            const client = getOpenAI();
            const mod = await client.moderations.create({ model: 'omni-moderation-latest', input: text });
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

// ICT Questions Import Function
export const importICTQuestions = functions.https.onCall(async (data, context) => {
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

    console.log('Starting ICT questions import...');
    
    const fs = require('fs');
    const path = require('path');
    
    let importedCount = 0;
    const currentTime = Date.now();
    const currentDate = new Date().toISOString();
    
    // Years to import (2011-2022)
    const years = Array.from({ length: 12 }, (_, i) => 2011 + i);
    
    for (const year of years) {
      try {
        // Read questions and answers files
        const questionsPath = path.join(__dirname, '..', '..', 'assets', 'bece_ict', `bece_ict_${year}_questions.json`);
        const answersPath = path.join(__dirname, '..', '..', 'assets', 'bece_ict', `bece_ict_${year}_answers_fulltext.json`);
        
        // Skip if files don't exist
        if (!fs.existsSync(questionsPath) || !fs.existsSync(answersPath)) {
          console.log(`Skipping year ${year} - files not found`);
          continue;
        }
        
        const questionsData = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
        const answersData = JSON.parse(fs.readFileSync(answersPath, 'utf8'));
        
        // ICT questions are stored in multiple_choice object with keys like q1, q2, etc.
        const questionsObj = questionsData.multiple_choice || {};
        const answersObj = answersData.multiple_choice || {};
        
        // Get all question keys and sort them
        const questionKeys = Object.keys(questionsObj).sort((a, b) => {
          const numA = parseInt(a.replace('q', ''));
          const numB = parseInt(b.replace('q', ''));
          return numA - numB;
        });
        
        console.log(`Processing ${questionKeys.length} ICT questions for year ${year}`);
        
        // Import each question
        for (const qKey of questionKeys) {
          const question = questionsObj[qKey];
          const answerText = answersObj[qKey];
          
          if (!question || !answerText) {
            console.warn(`Missing question or answer for ${qKey} in year ${year}`);
            continue;
          }
          
          // Extract question number from key (e.g., "q1" -> 1)
          const questionNumber = parseInt(qKey.replace('q', ''));
          
          // Extract the correct answer letter from the answer text (e.g., "B. keyboard." -> "B")
          const correctAnswerLetter = answerText.split('.')[0].trim();
          
          const questionDoc = {
            id: `ict_${year}_q${questionNumber}`,
            questionText: question.question,
            type: 'multipleChoice',
            subject: 'ict',
            examType: 'bece',
            year: year.toString(),
            section: questionsData.variant || 'A',
            questionNumber: questionNumber,
            options: question.possibleAnswers || [],
            correctAnswer: correctAnswerLetter,
            explanation: `This is question ${questionNumber} from the ${year} BECE ICT exam.`,
            marks: 1,
            difficulty: 'medium',
            topics: ['Information and Communications Technology', 'BECE', year.toString()],
            createdAt: currentDate,
            updatedAt: currentDate,
            createdBy: 'system_import',
            isActive: true,
            metadata: {
              source: `BECE ${year}`,
              importDate: currentDate,
              verified: true,
              timestamp: currentTime
            }
          };
          
          try {
            await db.collection('questions').doc(questionDoc.id).set(questionDoc);
            importedCount++;
            
            if (importedCount % 50 === 0) {
              console.log(`Progress: Imported ${importedCount} questions...`);
            }
          } catch (error) {
            console.error(`Error importing question ${questionNumber} from year ${year}:`, error);
          }
        }
        
        console.log(`Completed year ${year}: imported ${questionKeys.length} questions`);
        
      } catch (yearError) {
        console.error(`Error processing year ${year}:`, yearError);
      }
    }
    
    console.log(`Successfully imported ${importedCount} ICT questions to Firestore!`);
    
    // Update metadata
    try {
      await db.collection('app_metadata').doc('content').set({
        ictQuestionsImported: true,
        ictQuestionsCount: importedCount,
        ictYears: years.map(y => y.toString()),
        lastIctImportTimestamp: currentTime,
        lastUpdated: currentDate
      }, { merge: true });
      console.log('Updated ICT content metadata');
    } catch (error) {
      console.error('Error updating metadata:', error);
    }
    
    return {
      success: true,
      message: `Successfully imported ${importedCount} ICT questions!`,
      questionsImported: importedCount,
      years: years.map(y => y.toString())
    };
    
  } catch (error) {
    console.error('Error importing ICT questions:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError('internal', `Failed to import ICT questions: ${errorMessage}`);
  }
});

// Expose the consolidated HTTP handler
// export { aiChatHttp };

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

// Secure image proxy: streams a Storage file to the client with long cache headers.
// Expects query param `path` pointing to the storage path (e.g. notes/<uid>/...).
// Authorization: Bearer <idToken> required. Only the owner (uid) or admins may access.
export const noteImageProxy = functions.region('us-central1').https.onRequest((req, res) => {
  corsHandler(req, res, async () => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
      res.status(204).send('');
      return;
    }

    try {
      const storagePath = (req.query?.path || req.body?.path || '').toString();
      if (!storagePath) {
        res.status(400).json({ error: 'Missing path parameter' });
        return;
      }

      const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }

      const idToken = authHeader.split(' ')[1];
      let decoded: any = null;
      try {
        decoded = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        res.status(401).json({ error: 'Invalid ID token' });
        return;
      }

      // Basic authorization: owner or admin
      const uid = decoded.uid;
      const role = decoded.role || decoded['role'] || decoded['admin'] || null;
      const isAdmin = role === 'super_admin' || role === 'school_admin' || (decoded && decoded['isAdmin']);

      // Allow if the path is under notes/<uid>/ or caller is admin
      if (!isAdmin) {
        if (!storagePath.startsWith(`notes/${uid}/`)) {
          res.status(403).json({ error: 'Not authorized to access this file' });
          return;
        }
      }

      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);
      const [exists] = await file.exists();
      if (!exists) {
        res.status(404).json({ error: 'File not found' });
        return;
      }

      // Try to get metadata to set content-type and cache headers
      try {
        const [metadata] = await file.getMetadata();
        const contentType = metadata.contentType || 'application/octet-stream';
        const etag = metadata.etag || metadata.generation || '';
        const size = metadata.size ? Number(metadata.size) : undefined;

        res.setHeader('Content-Type', contentType);
        // Allow CDN and browser caching for 1 day (adjust as needed)
        res.setHeader('Cache-Control', 'public, max-age=86400, s-maxage=86400');
        if (etag) res.setHeader('ETag', etag.toString());
        if (size) res.setHeader('Content-Length', size.toString());
      } catch (e) {
        // continue without metadata
      }

      // Stream the file
      const stream = file.createReadStream();
      stream.on('error', (err) => {
        console.error('noteImageProxy stream error', err);
        try { res.status(500).end(); } catch (_) {}
      });
      stream.pipe(res);
    } catch (err) {
      console.error('noteImageProxy error', err);
      try { res.status(500).json({ error: 'Internal server error' }); } catch (_) {}
    }
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
  initialSetupAdmin,
  recommendationsDaily,
  recommendationsRunNow,
  aiChatHttp: aiChatHttpStreaming, // expose the consolidated HTTP handler for hosting
  ingestDocs,
  ingestPDFs,
  ingestLocalPDFs,
  listPDFs,
  noteImageProxy
};

// Export the streaming AI chat function
export const aiChatHttp = aiChatHttpStreaming;

// -------------------------
// Server-side aggregation helpers
// -------------------------

// Callable: getClassAggregates
// Returns a paginated list of students for a class (teacher or school+grade) with lightweight aggregates
export const getClassAggregates = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const callerRole = (context.auth.token && context.auth.token.role) || '';
  if (!['teacher', 'school_admin', 'admin', 'super_admin'].includes(callerRole)) {
    throw new functions.https.HttpsError('permission-denied', 'Only teachers or admins may call this function');
  }

  try {
    const teacherId = data?.teacherId;
    const school = data?.school;
    const grade = data?.grade;
    const pageSize = Math.min(Math.max(parseInt(String(data?.pageSize || '50'), 10) || 50, 1), 200);
    const pageCursor = data?.pageCursor; // document id of last doc from previous page

    if (!teacherId && !(school && grade)) {
      throw new functions.https.HttpsError('invalid-argument', 'Provide either teacherId or both school and grade');
    }

    // Prefer reading from materialized studentSummaries where possible (lighter and indexed)
    let baseQuery: any = null;
    if (teacherId) {
      baseQuery = db.collection('studentSummaries').where('teacherId', '==', teacherId);
    } else {
      // require both school and grade to avoid expensive OR queries
      const normSchool = normalizeSchoolClass(school) || String(school);
      const normGrade = normalizeSchoolClass(grade) || String(grade).toLowerCase().replace(/\s+/g, '_');
      baseQuery = db.collection('studentSummaries').where('normalizedSchool', '==', normSchool).where('normalizedClass', '==', normGrade);
    }

    // option to include total count (uses aggregation count())
    const includeCount = !!data?.includeCount;

  // order and paginate by firstName for stable ordering when using studentSummaries
  let q: any = baseQuery.orderBy('firstName').limit(pageSize + 1);

    // If includeCount requested, use Firestore count aggregation (server-side)
    let totalCount: number | null = null;
    if (includeCount) {
      try {
        const agg = await baseQuery.count().get();
        totalCount = agg.data().count || 0;
      } catch (err) {
        // ignore if count aggregation not supported; leave null
        totalCount = null;
      }
    }

    if (pageCursor) {
      const lastSnap = await db.collection('users').doc(String(pageCursor)).get();
      if (lastSnap.exists) q = q.startAfter(lastSnap);
    }

    const snaps = await q.get();
    const docs = snaps.docs || [];

    // Determine next page cursor
    let nextPageCursor = null;
    let pageDocs = docs;
    if (docs.length > pageSize) {
      const last = docs[pageSize - 1];
      nextPageCursor = last.id;
      pageDocs = docs.slice(0, pageSize);
    }

  const students = await Promise.all(pageDocs.map(async (d: any) => {
      const data = d.data() || {};
      // Fetch additional user data for rank and other fields
      let userRank = null;
      let userAvatar = null;
      let calculatedAccuracy = data.avgPercent || 0;
      
      try {
        const userDoc = await db.collection('users').doc(d.id).get();
        if (userDoc.exists) {
          const userData = userDoc.data() || {};
          userRank = userData.currentRankName || userData.rankName || userData.rank || null;
          userAvatar = userData.profileImageUrl || userData.avatar || userData.presetAvatar || null;
        }
      } catch (err) {
        console.warn('Failed to fetch user data for', d.id, err);
      }
      
      // Calculate accuracy from quizzes if avgPercent is 0 or not available
      if (!calculatedAccuracy || calculatedAccuracy === 0) {
        try {
          const quizzesSnap = await db.collection('quizzes')
            .where('userId', '==', d.id)
            .limit(50)
            .get();
          
          if (!quizzesSnap.empty) {
            let totalPercentage = 0;
            let count = 0;
            
            quizzesSnap.docs.forEach((qDoc: any) => {
              const qData = qDoc.data() || {};
              let percent = null;
              
              if (qData.percentage !== undefined && qData.percentage !== null) {
                percent = Number(qData.percentage) || 0;
              } else if (qData.percent !== undefined && qData.percent !== null) {
                percent = Number(qData.percent) || 0;
              } else if (qData.correctAnswers !== undefined && qData.totalQuestions !== undefined) {
                const correct = Number(qData.correctAnswers) || 0;
                const total = Number(qData.totalQuestions) || 0;
                if (total > 0) percent = (correct / total) * 100;
              }
              
              if (percent !== null && !isNaN(percent)) {
                totalPercentage += percent;
                count++;
              }
            });
            
            if (count > 0) {
              calculatedAccuracy = totalPercentage / count;
            }
          }
        } catch (err) {
          console.warn('Failed to calculate accuracy for', d.id, err);
        }
      }
      
      return {
        uid: d.id,
        displayName: data.firstName && data.lastName ? `${data.firstName} ${data.lastName}` : (data.displayName || data.profile?.firstName || null),
        email: data.email || data.profile?.email || data.email || null,
        avatar: userAvatar || data.avatar || data.profile?.photoUrl || null,
        totalXP: data.totalXP || data.xp || 0,
        rank: userRank || data.rank || data.leaderboardRank || null,
        subjectsSolved: data.subjectsCount || data.subjectsSolvedCount || data.subjectsSolved || 0,
        questionsSolved: data.totalQuestions || data.questionsSolved || data.questionsSolvedCount || 0,
        avgPercent: calculatedAccuracy,
        raw: data
      };
    }));

    // Compute simple aggregates over the returned page (cheap)
    const totalXP = students.reduce((s: number, it: any) => s + (it.totalXP || 0), 0);
    const avgXP = students.length ? Math.round(totalXP / students.length) : 0;

    return {
      ok: true,
      students,
      pageSize: students.length,
      nextPageCursor,
      aggregates: {
        pageTotalXP: totalXP,
        pageAvgXP: avgXP
      }
      ,
      totalCount
    };

  } catch (e: any) {
    console.error('getClassAggregates error', e);
    throw new functions.https.HttpsError('internal', e?.message || 'Internal error');
  }
});

// Firestore trigger: keep simple materialized class aggregates when attempts are created.
// This is the start of Option B: materialized aggregates. It's intentionally simple —
// it updates counters on classAggregates/{schoolId}_{grade}.
export const onAttemptCreate_updateAggregates = functions.firestore
  .document('attempts/{attemptId}')
  .onCreate(async (snap, context) => {
    try {
      const attempt = snap.data() || {};
      const uid = attempt.userId || attempt.uid || attempt.createdBy;
      if (!uid) return;

      const userRef = db.collection('users').doc(uid);
      const userSnap = await userRef.get();
      if (!userSnap.exists) return;
      const user = userSnap.data() || {};

      // Only process students, not teachers
      if (user.role !== 'student') return;

  const rawSchool = user.tenant?.schoolId || user.school || null;
  const rawGrade = user.grade || user.class || null;
  if (!rawSchool || !rawGrade) return;

  const normSchool = normalizeSchoolClass(rawSchool) || String(rawSchool);
  const normGrade = normalizeSchoolClass(rawGrade) || String(rawGrade).toLowerCase().replace(/\s+/g, '_');
  const classId = `${String(normSchool)}_${String(normGrade)}`;
      const classRef = db.collection('classAggregates').doc(classId);

      const xpInc = typeof attempt.points === 'number' ? attempt.points : (attempt.xp || 0);

      // determine percent/score and question counts if available
      let percent: number | null = null;
      if (typeof attempt.percent === 'number') percent = attempt.percent;
      else if (attempt.score != null && attempt.total != null && Number(attempt.total) > 0) percent = (Number(attempt.score) / Number(attempt.total)) * 100;
      const questionsInAttempt = Number(attempt.totalQuestions || attempt.total || (Array.isArray(attempt.items) ? attempt.items.length : 0)) || 0;

      // Update class-level aggregates: increment xp, attempts, and optionally score sums/counts and question counts
      const classUpdate: any = {
        schoolId: rawSchool,
        grade: rawGrade,
        normalizedSchool: normSchool,
        normalizedClass: normGrade,
        totalAttempts: admin.firestore.FieldValue.increment(1),
        totalXP: admin.firestore.FieldValue.increment(xpInc),
        totalQuestions: admin.firestore.FieldValue.increment(questionsInAttempt),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      if (percent !== null && !Number.isNaN(percent)) {
        classUpdate.totalScoreSum = admin.firestore.FieldValue.increment(percent);
        classUpdate.totalScoreCount = admin.firestore.FieldValue.increment(1);
      }
      await classRef.set(classUpdate, { merge: true });

      // Update per-student summary: increment xp, questions solved, and update score aggregates (recompute avgPercent)
      const studentSummaryRef = db.collection('studentSummaries').doc(uid);
      try {
        // Use transaction to read-modify-write avgPercent reliably
        await db.runTransaction(async (tx) => {
          const sdoc = await tx.get(studentSummaryRef);
          const sdata = sdoc.exists ? sdoc.data() || {} : {};
          const prevSum = Number(sdata.totalScoreSum || 0);
          const prevCount = Number(sdata.totalScoreCount || 0);
          const newSum = prevSum + (percent !== null && !Number.isNaN(percent) ? percent : 0);
          const newCount = prevCount + (percent !== null && !Number.isNaN(percent) ? 1 : 0);

          const newAvg = newCount > 0 ? (newSum / newCount) : (sdata.avgPercent || 0);

          tx.set(studentSummaryRef, {
            uid,
            totalXP: admin.firestore.FieldValue.increment(xpInc),
            questionsSolved: admin.firestore.FieldValue.increment(1),
            normalizedSchool: normSchool,
            normalizedClass: normGrade,
            totalScoreSum: admin.firestore.FieldValue.increment(percent !== null && !Number.isNaN(percent) ? percent : 0),
            totalScoreCount: admin.firestore.FieldValue.increment(percent !== null && !Number.isNaN(percent) ? 1 : 0),
            avgPercent: newAvg,
            // record last activity
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        });
      } catch (e) {
        console.warn('Failed to update student summary transactionally', e);
        // Fallback: best-effort incremental update
        const sset: any = {
          uid,
          totalXP: admin.firestore.FieldValue.increment(xpInc),
          questionsSolved: admin.firestore.FieldValue.increment(1),
          normalizedSchool: normSchool,
          normalizedClass: normGrade,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        if (percent !== null && !Number.isNaN(percent)) {
          sset.totalScoreSum = admin.firestore.FieldValue.increment(percent);
          sset.totalScoreCount = admin.firestore.FieldValue.increment(1);
        }
        await studentSummaryRef.set(sset, { merge: true });
      }

      return true;
    } catch (err) {
      console.error('onAttemptCreate_updateAggregates error', err);
      return null;
    }
  });

// Admin callable: backfillClassAggregates
// Scans users and writes classAggregates and studentSummaries documents. Admin-only.
export const backfillClassAggregates = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  const callerRole = (context.auth.token && context.auth.token.role) || '';
  const adminEmail = 'studywithuriel@gmail.com';
  if (!['super_admin', 'admin', 'school_admin'].includes(callerRole) && context.auth.token.email !== adminEmail) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins may run backfill');
  }

  try {
    const batchSize = 500;
    let last: any = null;
  const classAcc: Record<string, { schoolId: string; grade: string; normalizedSchool?: string | null; normalizedClass?: string | null; totalXP: number; totalStudents: number; totalAttempts: number; totalScoreSum?: number; totalScoreCount?: number; totalQuestions?: number; totalSubjects?: number; }> = {};

    while (true) {
      let q: any = db.collection('users').where('role', '==', 'student').limit(batchSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      for (const d of snap.docs) {
        const u = d.data() || {};
        const uid = d.id;
        const rawSchool = u.tenant?.schoolId || u.school || null;
        const rawGrade = u.grade || u.class || null;
        if (!rawSchool || !rawGrade) continue;
        const normSchool = normalizeSchoolClass(rawSchool) || String(rawSchool);
        const normGrade = normalizeSchoolClass(rawGrade) || String(rawGrade).toLowerCase().replace(/\s+/g, '_');
        const classId = `${String(normSchool)}_${String(normGrade)}`;
        const xp = (u.totalXP as number) || (u.xp as number) || 0;
        // compute quiz-based metrics for this student (avg percent, subjects count, total questions)
        let studentAvgPercent = 0;
        let studentScoreSum = 0;
        let studentScoreCount = 0;
        let studentTotalQuestions = 0;
        const studentSubjects = new Set<string>();
        try {
          const qs = await db.collection('quizzes').where('userId', '==', uid).get();
          for (const qd of qs.docs) {
            const qdData: any = qd.data() || {};
            if (qdData.percent != null) {
              const p = typeof qdData.percent === 'number' ? qdData.percent : parseFloat(String(qdData.percent)) || 0;
              studentScoreSum += p;
              studentScoreCount += 1;
            } else if (qdData.score != null && qdData.total != null) {
              const score = Number(qdData.score) || 0;
              const total = Number(qdData.total) || 0;
              if (total > 0) {
                const pct = (score / total) * 100;
                studentScoreSum += pct;
                studentScoreCount += 1;
              }
            }
            const subj = (qdData.subject || qdData.collectionName || '').toString();
            if (subj) studentSubjects.add(subj);
            studentTotalQuestions += Number(qdData.totalQuestions || qdData.total || 0) || 0;
          }
          if (studentScoreCount > 0) studentAvgPercent = studentScoreSum / studentScoreCount;
        } catch (e) {
          console.warn('Failed to compute quizzes for user', uid, e);
        }
  if (!classAcc[classId]) classAcc[classId] = { schoolId: String(rawSchool), grade: String(rawGrade), normalizedSchool: normSchool, normalizedClass: normGrade, totalXP: 0, totalStudents: 0, totalAttempts: 0, totalScoreSum: 0, totalScoreCount: 0, totalQuestions: 0, totalSubjects: 0 };
  classAcc[classId].totalXP += xp;
  classAcc[classId].totalStudents += 1;
  classAcc[classId].totalScoreSum = (classAcc[classId].totalScoreSum || 0) + studentScoreSum;
  classAcc[classId].totalScoreCount = (classAcc[classId].totalScoreCount || 0) + studentScoreCount;
  classAcc[classId].totalQuestions = (classAcc[classId].totalQuestions || 0) + studentTotalQuestions;
  classAcc[classId].totalSubjects = (classAcc[classId].totalSubjects || 0) + studentSubjects.size;

        // Write per-student summary doc (include computed quiz metrics)
        await db.collection('studentSummaries').doc(uid).set({
          uid,
          totalXP: xp,
          questionsSolved: (u.questionsSolved as number) || (u.questionsSolvedCount as number) || 0,
          normalizedSchool: normSchool,
          normalizedClass: normGrade,
          teacherId: u.teacherId || null,
          firstName: u.profile?.firstName || u.firstName || null,
          lastName: u.profile?.lastName || u.lastName || null,
          email: u.email || u.profile?.email || null,
          avgPercent: studentAvgPercent,
          totalScoreSum: studentScoreSum,
          totalScoreCount: studentScoreCount,
          subjectsCount: studentSubjects.size,
          totalQuestions: studentTotalQuestions,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < batchSize) break;
    }

    // Commit class aggregates
    const writes: Promise<any>[] = [];
    for (const cid of Object.keys(classAcc)) {
      const c = classAcc[cid];
      writes.push(db.collection('classAggregates').doc(cid).set({
        schoolId: c.schoolId,
        grade: c.grade,
        normalizedSchool: c.normalizedSchool,
        normalizedClass: c.normalizedClass,
        totalXP: c.totalXP,
        totalStudents: c.totalStudents,
        totalScoreSum: c.totalScoreSum || 0,
        totalScoreCount: c.totalScoreCount || 0,
        totalQuestions: c.totalQuestions || 0,
        totalSubjects: c.totalSubjects || 0,
        avgScorePercent: (c.totalScoreCount && c.totalScoreCount > 0) ? ((c.totalScoreSum || 0) / (c.totalScoreCount || 1)) : 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true }));
    }

    await Promise.all(writes);

    return { ok: true, classesUpdated: Object.keys(classAcc).length };
  } catch (e) {
    console.error('backfillClassAggregates error', e);
    throw new functions.https.HttpsError('internal', 'Backfill failed');
  }
});

// Admin callable: backfill a single page of users. Returns nextCursor for resumable processing.
export const backfillClassPage = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  const callerRole = (context.auth.token && context.auth.token.role) || '';
  const adminEmail = 'studywithuriel@gmail.com';
  if (!['super_admin', 'admin', 'school_admin'].includes(callerRole) && context.auth.token.email !== adminEmail) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins may run backfill');
  }

  try {
    const pageSize = Math.min(Math.max(Number(data?.pageSize) || 500, 1), 1000);
    const lastUid = data?.lastUid || null;

    // Progress tracking doc for resumable backfill
    const progressRef = db.collection('backfillProgress').doc('studentBackfill');
    // Read existing cumulative count (if any)
    const existingProgress = (await progressRef.get()).data() || {};
    const prevCumulative = Number(existingProgress.cumulativeProcessed || 0);
    // Mark progress as running for this page
    await progressRef.set({
      status: 'running',
      pageSize,
      lastRequestedCursor: lastUid || null,
      lastStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedCount: 0,
      cumulativeProcessed: prevCumulative
    }, { merge: true });

    let q: any = db.collection('users').where('role', '==', 'student').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastUid) q = q.startAfter(String(lastUid));
    const snap = await q.get();
    if (snap.empty) return { ok: true, processed: 0, nextCursor: null };

    const classAcc: Record<string, { schoolId: string; grade: string; normalizedSchool?: string | null; normalizedClass?: string | null; totalXP: number; totalStudents: number; totalAttempts: number; totalScoreSum?: number; totalScoreCount?: number; totalQuestions?: number; totalSubjects?: number; }> = {};

    for (const d of snap.docs) {
      const u = d.data() || {};
      const uid = d.id;
      const rawSchool = u.tenant?.schoolId || u.school || null;
      const rawGrade = u.grade || u.class || null;
      if (!rawSchool || !rawGrade) continue;
      const normSchool = normalizeSchoolClass(rawSchool) || String(rawSchool);
      const normGrade = normalizeSchoolClass(rawGrade) || String(rawGrade).toLowerCase().replace(/\s+/g, '_');
      const classId = `${String(normSchool)}_${String(normGrade)}`;
      const xp = (u.totalXP as number) || (u.xp as number) || 0;

      // compute quiz metrics for student
      let studentScoreSum = 0;
      let studentScoreCount = 0;
      let studentTotalQuestions = 0;
      const studentSubjects = new Set<string>();
      try {
        const qs = await db.collection('quizzes').where('userId', '==', uid).get();
        for (const qd of qs.docs) {
          const qdData = qd.data() || {};
          if (qdData.percent != null) {
            const p = typeof qdData.percent === 'number' ? qdData.percent : parseFloat(String(qdData.percent)) || 0;
            studentScoreSum += p;
            studentScoreCount += 1;
          } else if (qdData.score != null && qdData.total != null) {
            const score = Number(qdData.score) || 0;
            const total = Number(qdData.total) || 0;
            if (total > 0) {
              const pct = (score / total) * 100;
              studentScoreSum += pct;
              studentScoreCount += 1;
            }
          }
          const subj = (qdData.subject || qdData.collectionName || '').toString();
          if (subj) studentSubjects.add(subj);
          studentTotalQuestions += Number(qdData.totalQuestions || qdData.total || 0) || 0;
        }
      } catch (e) { console.warn('backfillClassPage: failed to query quizzes for', uid, e); }

      if (!classAcc[classId]) classAcc[classId] = { schoolId: String(rawSchool), grade: String(rawGrade), normalizedSchool: normSchool, normalizedClass: normGrade, totalXP: 0, totalStudents: 0, totalAttempts: 0, totalScoreSum: 0, totalScoreCount: 0, totalQuestions: 0, totalSubjects: 0 };
      classAcc[classId].totalXP += xp;
      classAcc[classId].totalStudents += 1;
      classAcc[classId].totalScoreSum = (classAcc[classId].totalScoreSum || 0) + studentScoreSum;
      classAcc[classId].totalScoreCount = (classAcc[classId].totalScoreCount || 0) + studentScoreCount;
      classAcc[classId].totalQuestions = (classAcc[classId].totalQuestions || 0) + studentTotalQuestions;
      classAcc[classId].totalSubjects = (classAcc[classId].totalSubjects || 0) + studentSubjects.size;

      // Write per-student summary
      await db.collection('studentSummaries').doc(uid).set({
        uid,
        totalXP: xp,
        questionsSolved: (u.questionsSolved as number) || (u.questionsSolvedCount as number) || 0,
        normalizedSchool: normSchool,
        normalizedClass: normGrade,
        teacherId: u.teacherId || null,
        firstName: u.profile?.firstName || u.firstName || null,
        lastName: u.profile?.lastName || u.lastName || null,
        email: u.email || u.profile?.email || null,
        avgPercent: studentScoreCount > 0 ? (studentScoreSum / studentScoreCount) : 0,
        totalScoreSum: studentScoreSum,
        totalScoreCount: studentScoreCount,
        subjectsCount: studentSubjects.size,
        totalQuestions: studentTotalQuestions,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }

    // write class aggregates for this page
    const writes: Promise<any>[] = [];
    for (const cid of Object.keys(classAcc)) {
      const c = classAcc[cid];
      writes.push(db.collection('classAggregates').doc(cid).set({
        schoolId: c.schoolId,
        grade: c.grade,
        normalizedSchool: c.normalizedSchool,
        normalizedClass: c.normalizedClass,
        totalXP: c.totalXP,
        totalStudents: c.totalStudents,
        totalScoreSum: c.totalScoreSum || 0,
        totalScoreCount: c.totalScoreCount || 0,
        totalQuestions: c.totalQuestions || 0,
        totalSubjects: c.totalSubjects || 0,
        avgScorePercent: (c.totalScoreCount && c.totalScoreCount > 0) ? ((c.totalScoreSum || 0) / (c.totalScoreCount || 1)) : 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true }));
    }
    await Promise.all(writes);

    const last = snap.docs[snap.docs.length - 1];
    const nextCursor = last ? last.id : null;

    // Update progress doc with results of this page
    try {
      await progressRef.set({
        status: nextCursor ? 'running' : 'completed',
        lastProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedCount: snap.docs.length,
        cumulativeProcessed: admin.firestore.FieldValue.increment(snap.docs.length),
        lastCursor: nextCursor || null
      }, { merge: true });
    } catch (e) {
      console.warn('backfillClassPage: failed to update progress doc', e);
    }

    return { ok: true, processed: snap.docs.length, nextCursor };
  } catch (e) {
    console.error('backfillClassPage error', e);
    try {
      await db.collection('backfillProgress').doc('studentBackfill').set({ status: 'error', lastError: ((e as any)?.message || String(e)) || 'unknown', lastErrorAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    } catch (ee) { console.warn('backfillClassPage: failed to write error progress', ee); }
    throw new functions.https.HttpsError('internal', 'Backfill page failed');
  }
});

// Export AI Quiz Generation
export { generateAIQuiz } from './generateAIQuiz';