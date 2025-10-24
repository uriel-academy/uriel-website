import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

// Minimal, single HTTP AI endpoint for Uri (region: us-central1)
// - CORS allow-list
// - Firebase ID token auth
// - Time-sensitive guard (no live sources)
// - Moderation (omni-moderation-latest)
// - Writes aiChats log (best-effort)

if (!admin.apps.length) admin.initializeApp();

const ALLOWED_ORIGINS = ['https://uriel.academy', 'https://uriel-academy-41fb0.web.app'];
const openai = new OpenAI({ apiKey: functions.config().openai?.key });
const modelName = functions.config().openai?.model ?? 'gpt-4o-mini';

const timeSensitiveRe = /(?:today|now|latest|current|this year|price|fees?|results?|timetable|date|schedule|deadline|president|minister|bece|wassce|waec|ges)/i;

const systemPrompt = `You are **Uri**, a friendly, witty, Ghana-aware study buddy for ages 10–21.
- British English. Be concise and conversational.
- No auto headings or numbering unless the user asks for steps/outline/table.
- Use light bullets sparingly when it improves clarity.
- Do not guess time-sensitive facts (dates/schedules/presidents/fees/results). If unsure, say you don’t know and offer how to check.
- Encourage, never snark. Casual chats OK (football, music, life).
- For maths, render clearly (MathJax/KaTeX) but don’t dump LaTeX unless asked.
`;

export const aiChatHttp = functions.region('us-central1').https.onRequest(async (req, res) => {
  // CORS
  const origin = (req.get('Origin') || req.get('origin') || '').toString();
  res.set('Vary', 'Origin');
  if (ALLOWED_ORIGINS.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  } else {
    // default to first allowed origin (safe fallback)
    res.set('Access-Control-Allow-Origin', ALLOWED_ORIGINS[0]);
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    if (!functions.config().openai?.key) {
      res.status(500).json({ status: 'error', error: 'AI provider not configured' });
      return;
    }

    const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ status: 'error', error: 'Missing Authorization Bearer token' });
      return;
    }
    const idToken = authHeader.split(' ')[1];

    let uid: string | null = null;
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      uid = decoded.uid;
    } catch (e) {
      res.status(401).json({ status: 'error', error: 'Invalid ID token' });
      return;
    }

    const body = req.body || {};
    const question = (body.message || '').toString().trim();

    if (!question) {
      res.status(400).json({ status: 'error', error: 'Empty message' });
      return;
    }

    // Time-sensitive guard
    if (timeSensitiveRe.test(question)) {
      const canned = "I don’t have live sources right now, so I can’t confirm the latest update. For current info, please check WAEC/GES or trusted news. I can still help you study or explain the topic.";
      res.json({ status: 'ok', reply: canned, model: modelName });
      return;
    }

    // Moderation
    try {
      const mod = await openai.moderations.create({ model: 'omni-moderation-latest', input: question });
      const flagged = (mod as any)?.results?.[0]?.flagged;
      if (flagged) {
        res.status(403).json({ status: 'error', error: 'Message flagged by moderation' });
        return;
      }
    } catch (e) {
      // Fail-soft: log and continue
      console.warn('Moderation check failed', e);
    }

    // Build messages
    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: question }
    ];

    // Call OpenAI
    let reply = '';
    try {
      const completion = await openai.chat.completions.create({
        model: modelName,
        messages: messages as any,
        temperature: 0.2,
        max_tokens: 800
      });
      reply = completion?.choices?.[0]?.message?.content || '';
    } catch (err) {
      console.error('OpenAI completion failed', err);
      res.status(500).json({ status: 'error', error: 'AI completion failed' });
      return;
    }

    // Best-effort logging
    (async () => {
      try {
        await admin.firestore().collection('aiChats').add({ userId: uid, question, reply, model: modelName, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      } catch (e) {
        console.warn('Failed to write aiChats log', e);
      }
    })();

    res.json({ status: 'ok', reply, model: modelName });
  } catch (err) {
    console.error('aiChatHttp error', err);
    res.status(500).json({ status: 'error', error: 'Internal server error' });
  }
});
