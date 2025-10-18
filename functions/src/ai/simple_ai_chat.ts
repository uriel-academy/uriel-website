import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

if (!admin.apps.length) admin.initializeApp();

// Allowed origins for CORS - update with your production origins
const ALLOWED_ORIGINS = ['https://uriel.academy', 'https://uriel-academy-41fb0.web.app'];

function getOpenAIClient() {
  const key = functions.config().openai?.key;
  if (!key) return null;
  return new OpenAI({ apiKey: key });
}

export const aiChatHttp = functions.region('us-central1').https.onRequest(async (req, res) => {
  // Handle CORS preflight
  const origin = req.get('Origin') || req.get('origin') || '';
  if (ALLOWED_ORIGINS.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  } else {
    res.set('Access-Control-Allow-Origin', ALLOWED_ORIGINS[0]);
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const openai = getOpenAIClient();
    if (!openai) {
      res.status(500).json({ error: 'AI provider not configured' });
      return;
    }

    const userMessage = (req.body?.message ?? '').toString().slice(0, 4000);

    // Best-effort moderation (non-blocking)
    try {
      await openai.moderations.create({ model: 'omni-moderation-latest', input: userMessage });
    } catch (e) {
      console.warn('Moderation failed (non-blocking)', e instanceof Error ? e.message : e);
    }

    const resp = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0.3,
      messages: [
        { role: 'system', content: "You are Uri, the Uriel Academy study assistant. Be concise, Ghana-specific when relevant." },
        { role: 'user', content: userMessage }
      ],
    });

    const reply = resp?.choices?.[0]?.message?.content ?? '';
    res.json({ reply });
    return;
  } catch (err: any) {
    console.error('aiChatHttp error', err instanceof Error ? err.stack || err.message : String(err));
    res.status(500).json({ error: err?.message ?? 'Server error' });
    return;
  }
});

export default { aiChatHttp };
