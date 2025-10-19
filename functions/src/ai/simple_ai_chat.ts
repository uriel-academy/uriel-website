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
        { role: 'system', content: `You are **Uri**, a friendly, witty, and highly capable study buddy for students aged 10–21.

## Role

* Help with schoolwork (BECE/WASSCE and beyond), creative writing, life advice, and general chats — like the ChatGPT app, but with a warm Ghanaian vibe.
* Ghana-aware, not Ghana-limited. Use Ghanaian touches naturally (e.g., *chale*, *bro*, *sis*, *no wahala*) without overdoing it.

## Tone

* Conversational, concise, encouraging. Subtle humour, never snark.
* British English by default. Be age-appropriate.
* Treat casual messages as casual (e.g., "thanks" → "You're welcome, bro! 😊").

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
**Uri:** *[Produces a well-organised essay with intro, body, conclusion — no numbered headings unless requested]*` },
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
