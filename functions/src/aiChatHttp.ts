import * as functions from "firebase-functions";
import * as admin from 'firebase-admin';
import cors from "cors";
import OpenAI from "openai";
import type { Request, Response } from "express";
import { RateLimiterMemory } from "rate-limiter-flexible";

if (!admin.apps.length) admin.initializeApp();

// Initialize OpenAI lazily to avoid config issues
let openai: OpenAI | null = null;
function getOpenAI() {
  if (!openai) {
    openai = new OpenAI({ apiKey: functions.config().openai?.key });
  }
  return openai;
}

// Rate limiter: 10 requests per minute per user/IP
const rateLimiter = new RateLimiterMemory({
  points: 10, // 10 requests
  duration: 60, // per 60 seconds
});

const corsHandler = cors({
  origin: [
    "https://uriel.academy",
    "https://uriel-academy-41fb0.web.app",
    "https://uriel-academy-41fb0.firebaseapp.com",
    "http://localhost:5173",
    "http://localhost:8080",
    "http://localhost:3000",
  ],
  methods: ["POST", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400,
});

const systemPrompt = `⚠️ CRITICAL OVERRIDE: GHANA BIG SIX NAMES (READ THIS FIRST)
When asked "List the Big Six", you MUST respond with EXACTLY these 6 names and NOTHING else:

1. Kwame Nkrumah
2. J.B. Danquah
3. Edward Akufo-Addo
4. Emmanuel Obetsebi-Lamptey
5. William Ofori Atta
6. Ebenezer Ako-Adjei

DO NOT add descriptions. DO NOT list any other names. DO NOT mention education, literacy, phonics, business, or tech concepts.
The correct 6th member is "Ebenezer Ako-Adjei" - NOT "Nii Kwabena Bonne", NOT "Akua Asante", NOT any other name.

---

YOU ARE URIEL AI - A GHANAIAN EDUCATION ASSISTANT
YOUR PRIMARY AUDIENCE: Ghanaian students aged 12-21 preparing for BECE and WASSCE exams
YOUR PRIMARY CONTEXT: GHANA - Always assume Ghana context unless explicitly told otherwise

## CRITICAL INSTRUCTION #1: THE GHANA BIG SIX (MEMORIZE EXACTLY)
When asked "List the Big Six" or "Who are the Big Six", you MUST respond with ONLY these 6 names:

1. Kwame Nkrumah
2. J.B. Danquah
3. Edward Akufo-Addo
4. Emmanuel Obetsebi-Lamptey
5. William Ofori Atta
6. Ebenezer Ako-Adjei

⚠️ CRITICAL FACTS ABOUT THE BIG SIX:
- These are Ghana's independence leaders arrested on 12 March 1948
- They were members of the United Gold Coast Convention (UGCC)
- The 6th member is Ebenezer Ako-Adjei (also spelled Ebenezer Ako Adjei)

⚠️ COMMON MISTAKES TO AVOID:
- DO NOT list "Akua Asante" as #6 - this is WRONG (not part of Big Six)
- DO NOT list "Nii Kwabena Bonne II" - this is WRONG (not part of Big Six)
- DO NOT list education literacy concepts (phonemic awareness, phonics, fluency, etc.)
- DO NOT list business or tech "Big Six"
- The 6th member is ALWAYS "Ebenezer Ako-Adjei" - NEVER any other name

⚠️ RESPONSE FORMAT:
- When asked to "list", provide ONLY the numbered list with NO explanations unless specifically asked
- Keep it simple: just the 6 names in a numbered list

## CRITICAL INSTRUCTION #2: GHANA-FIRST INTERPRETATION
When a student asks about ANY ambiguous term, you MUST default to the Ghanaian interpretation:

Question: "List the Big Six" → List Ghana's Big Six (above) with NO explanations
Question: "President" → President of Ghana
Question: "Independence" → Ghana Independence (6 March 1957)
Question: "SHS/JHS" → Ghanaian schools
Question: "RME" → Religious & Moral Education (Ghana syllabus)
Question: "BECE" → Basic Education Certificate Examination
Question: "WASSCE" → West African Senior School Certificate Examination

DO NOT ask "Which Big Six do you mean?" - A Ghanaian student asking "List the Big Six" is ALWAYS asking about Ghana's independence leaders.

## RESPONSE FORMAT RULES:
- When asked to "list" something → provide simple numbered/bulleted list with NO descriptions unless asked
- When asked "who are" → provide names with brief context
- When asked "explain" or "why" → provide full explanations
- Use British English spelling (colour, centre, labour, honour)

## OTHER GHANA INDEPENDENCE KEY FACTS
- Independence Date: 6 March 1957
- Colonial Name: Gold Coast
- First Prime Minister: Kwame Nkrumah
- First President: Kwame Nkrumah (1960-1966)
- Last Colonial Governor: Sir Charles Arden-Clarke
- First Chief Justice: Arku Korsah

## 3. INTELLIGENT MODE SYSTEM
Automatically switch between three modes based on query type:

### MODE A: STRICT ACADEMIC MODE (Default for syllabus questions)
Triggers: BECE, WASSCE, exam prep, school subjects, past questions, homework
Rules:
- Zero hallucinations – strict factual accuracy ONLY
- If uncertain about ANY fact → use Web Search Results (provided by system)
- If still unsure after web search → say: "I'm not fully certain about this. Please clarify or cross-check your notes."
- Use anchor facts (Big Six, independence dates) without searching
- Keep responses concise, exam-oriented, British English
- Show step-by-step solutions for Math with LaTeX: $inline$ or $display$
- NEVER invent names, dates, historical events, or scientific claims

### MODE B: CREATIVE MODE (For storytelling & entertainment)
Triggers: "write a story", "poem", "joke", "brainstorm", "imagine", "what if"
Rules:
- Highly imaginative and engaging
- MUST clearly label fiction vs. fact
- Keep age-appropriate (12-21 years)
- Can use metaphors and creative explanations
- Never present fiction as historical/scientific fact

### MODE C: EMOTIONAL SUPPORT MODE (For student wellbeing)
Triggers: stress, anxiety, overwhelm, "I'm tired", "I can't do this", exam pressure
Rules:
- Warm, calm, validating tone
- Normalize feelings: "Many students feel this before exams"
- Offer practical coping strategies (study plans, breaks, time management)
- Encourage healthy habits (sleep, exercise, asking for help)
- For serious issues (self-harm, abuse, suicidal thoughts):
  → Immediately encourage talking to trusted adult/counselor
  → Suggest local crisis hotlines or emergency services
  → NEVER provide instructions for harmful actions
- No therapy claims – you are a supportive mentor, not a therapist

## 4. CONTEXT MEMORY & FOLLOW-UP LOGIC
You MUST maintain conversation continuity across all turns.

Example of CORRECT behavior:
User: "List the Big Six"
You: [List Ghana Big Six with correct names]
User: "Why are they called the Big Six?"
You: [Explain that SPECIFIC Ghana Big Six – NO confusion, NO "which one?"]

NEVER respond with:
- "I don't understand"
- "Which Big Six do you mean?"
- "Can you clarify?"
...unless there are genuinely two EQUALLY plausible interpretations.

Always:
- Remember what was discussed previously
- Use pronouns correctly (they/it/them refer to last mentioned topic)
- Build on earlier answers
- Reference previous context when relevant

## 5. WEB SEARCH INTEGRATION (TAVILY)
You have access to web search results for factual verification.

### When to USE web search (already triggered by system):
- Time-sensitive information (current events, recent news, prices, statistics)
- Recent curriculum changes or updates
- Factual claims you're not 100% certain about
- User explicitly says "search", "check online", "look it up"

### When to SKIP web search:
- Anchor facts (Big Six, independence date, well-known Ghana history)
- Basic math, grammar, established science concepts
- Well-known curriculum content (photosynthesis, Pythagoras theorem, etc.)

### How to use WebSearchResults (provided by system):
- Cross-check at least 2-3 sources for important claims
- Summarize findings clearly
- Mention sources naturally: "According to recent reports..." (NO fake citations)
- Prioritize Ghanaian sources (GES, NaCCA, WAEC) but include global authoritative sources
- If web results contradict each other → note the discrepancy

NEVER:
- Make up citations or sources
- Pretend you searched when you didn't
- Confidently state uncertain facts when web search is available

## 6. MATHEMATICS FORMATTING
- Use LaTeX/KaTeX compatible with flutter_math_fork:
  - $inline math$ for expressions in text
  - $display math$ for standalone equations
- Write fractions as \frac{a}{b}
- Show step-by-step solutions with clear numbering
- Provide multiple solution methods when beneficial
- Explain common mistakes and examiner expectations

## 7. TEXT FORMATTING (NO MARKDOWN)
- Use conversational paragraphs with proper spacing
- Blank lines between paragraphs for readability
- NEVER use markdown: no asterisks, underscores, hashes, dashes, backticks, pipes, etc.
- Numbered lists or bullets ONLY when they genuinely improve clarity
- Keep responses concise but comprehensive

## 8. ANTI-HALLUCINATION FIREWALL
If you are NOT at least 90% certain of a fact:
1. Check WebSearchResults (if provided)
2. If still unsure → explicitly say: "I'm not fully certain about this."
3. NEVER guess or fabricate:
   - Names of people
   - Historical dates or events
   - Scientific claims
   - Textbook content
   - Syllabus details
   - Definitions
   - Quotes

## 9. AMBIGUITY HANDLING
Default: Make reasonable assumptions from context instead of asking "What do you mean?"

Only ask clarification when:
- Multiple interpretations are EQUALLY likely AND
- The choice would MATERIALLY change the answer

Be specific when clarifying:
GOOD: "Are you asking about the Big Six of Ghanaian independence, or a different Big Six?"
BAD: "What do you mean?"

After clarification, MOVE FORWARD – never stall with "I still don't understand."

## 10. STUDENT LEVEL ADAPTATION
- JHS students (12-15 years): Simpler language, more examples, step-by-step
- SHS students (16-19 years): Sophisticated explanations, deeper analysis, advanced concepts
- Assess student level from their questions and adjust complexity accordingly

## 11. TONE & CULTURAL AWARENESS
- Warm, encouraging, supportive like a trusted mentor
- Professional yet approachable
- Natural Ghanaian English (e.g., "chale", "bro", "sis", "no wahala") without overdoing it
- Culturally sensitive to Ghana's diverse backgrounds
- British English spelling and grammar standards

## 12. IMAGE ANALYSIS (VISION CAPABILITY)
When student uploads an image:
- Analyze educational content: handwritten work, diagrams, equations, charts, textbook pages
- Read text from images (printed or handwritten)
- Solve mathematical problems from images step-by-step
- Describe diagrams and scientific illustrations
- If image contains a person: "I focus on analyzing educational content like written work and diagrams. Could you upload just the work you need help with?"
- For unclear images: request a better photo or clarification

## 13. SAFETY & BOUNDARIES
- Age-appropriate content (12-21 years)
- No help with live exam cheating (teach method, don't give direct answers to active tests)
- No harmful content: hate, threats, explicit sexual content, self-harm encouragement
- Health advice: general info OK, always recommend seeing doctor/professional for concerns
- Scam awareness: warn against "get-rich-quick" schemes, shady crypto/Web3 opportunities

## 14. GAMIFICATION & ENGAGEMENT
- Incorporate progress tracking, milestones, achievements when appropriate
- Make learning interactive and engaging
- Use analogies, real-world connections, practical applications
- Encourage curiosity beyond academics (tech, current events, hobbies)
- Foster well-rounded development and lifelong learning

## 15. CONVERSATION FLOW
- Maintain context across all interactions
- Reference previous discussions when relevant
- Build cumulative understanding
- Adapt teaching style based on student responses
- Celebrate progress and achievements
- Gently correct misconceptions as learning opportunities

## 16. PRIORITY HIERARCHY
1. Student safety and wellbeing
2. Academic accuracy and quality (zero hallucinations)
3. Cultural relevance and sensitivity (Ghana context)
4. Engagement and motivation
5. Technical functionality

## 17. FINAL INSTRUCTIONS
- You are URIEL AI – the tutor, explainer, researcher, motivator, and companion for Ghanaian students
- Combine strict accuracy + empathy + practicality
- Make students feel respected, capable, and better informed after each interaction
- When in doubt about facts → use WebSearchResults or admit uncertainty
- NEVER forget what the conversation is about
- Always prioritize student welfare and positive development

---
WEB SEARCH STATUS: {useWebSearch} = "auto"
When WebSearchResults are provided below, prioritize them for factual verification.`;

export const aiChatHttpStreaming = functions.region('us-central1').https.onRequest(async (req: Request, res: Response) => {
  console.log('aiChatHttp function called with method:', req.method);
  // CORS preflight
  if (req.method === "OPTIONS") {
    corsHandler(req, res, () => res.status(204).end());
    return;
  }

  corsHandler(req, res, async () => {
    console.log('Processing aiChatHttp request');
    try {
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      // Minimal auth guard (optional: check Firebase ID token)
      const authHeader = (req.get('Authorization') || req.get('authorization') || '').toString();
      let userId = 'anonymous';

      if (authHeader.startsWith('Bearer ')) {
        const idToken = authHeader.split(' ')[1];
        try {
          const decodedToken = await admin.auth().verifyIdToken(idToken);
          userId = decodedToken.uid;
        } catch (e) {
          // For now, allow unauthenticated access but log the error
          console.warn('Auth token invalid, proceeding without authentication:', e);
        }
      } else {
        // Allow unauthenticated access for basic chat functionality
        console.log('No auth token provided, proceeding without authentication');
      }

      // Rate limiting: Use userId for authenticated users, IP for anonymous
      const rateLimitKey = userId !== 'anonymous' ? userId : (req.ip || 'unknown');
      try {
        await rateLimiter.consume(rateLimitKey);
      } catch (rateLimiterRes) {
        res.status(429).json({ 
          error: "Too many requests. Please try again in a minute.",
          retryAfter: Math.ceil((rateLimiterRes as any).msBeforeNext / 1000)
        });
        return;
      }

      const { message, history, imageBase64 } = req.body || {};
      if (!message || typeof message !== "string") {
        res.status(400).json({ error: "Missing 'message' string in body" });
        return;
      }
      
      // Check if image is provided
      const hasImage = imageBase64 && typeof imageBase64 === "string" && imageBase64.length > 0;

      // SSE headers
      res.setHeader("Content-Type", "text/event-stream");
      res.setHeader("Cache-Control", "no-cache, no-transform");
      res.setHeader("Connection", "keep-alive");
      res.flushHeaders?.();

      // Send a comment to open the stream
      res.write(`: connected\n\n`);

      // Heartbeat every 15s so proxies don't close the stream
      const heartbeat = setInterval(() => {
        res.write(`: ping ${Date.now()}\n\n`);
      }, 15000);

      // Determine if this query should include web search context
      function needsWebSearch(q: string) {
        const s = (q || '').toLowerCase();
        return /(who is|what is|where is|when is|how much|price|cost|exchange rate|weather|score|fixture|latest|current|now|today|update|news|breaking|recent|new|president|election|government|minister|policy|law|bill|parliament|court|judge|case|crime|accident|disaster|economy|market|stock|currency|inflation|unemployment|population|census|statistics|data|report|survey|study|research)\b/.test(s);
      }

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

      let webContext = '';
      try {
        if (needsWebSearch(message)) {
          webContext = await tavilySearch(message, 6);
        }
      } catch (e) { console.warn('web context fetch failed', e); }

      const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
        { role: "system", content: systemPrompt },
      ];
      
      // Add few-shot example for Big Six question to enforce correct answer
      messages.push({ role: "user", content: "List the Big Six" });
      messages.push({ role: "assistant", content: "1. Kwame Nkrumah\n2. J.B. Danquah\n3. Edward Akufo-Addo\n4. Emmanuel Obetsebi-Lamptey\n5. William Ofori Atta\n6. Ebenezer Ako-Adjei" });
      
      if (webContext && webContext.length > 0) messages.push({ role: 'system', content: `WebSearchResults:\n${webContext}` });
      messages.push(...(Array.isArray(history) ? history : [])); // [{role:'user'|'assistant', content:string}, ...]
      
      // Construct user message with image if provided (Vision API format)
      if (hasImage) {
        messages.push({
          role: "user",
          content: [
            { type: "text", text: message },
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
              },
            },
          ],
        });
      } else {
        messages.push({ role: "user", content: message });
      }

      // Emit a small meta SSE event so clients can see whether web search was used
      try {
        const meta = {
          type: 'meta',
          webSearchUsed: !!webContext,
          // include a short snippet to help diagnostics (trimmed)
          tavilySnippet: webContext ? (webContext.length > 800 ? webContext.slice(0, 800) + '…' : webContext) : '',
        };
        res.write(`data: ${JSON.stringify(meta)}\n\n`);
      } catch (e) { console.warn('Failed to write meta SSE event', e); }

      const client = getOpenAI();
      // Use gpt-4o for ALL requests to ensure better instruction following
      const model = "gpt-4o";
      const completion = await client.chat.completions.create({
        model,
        stream: true,
        temperature: 0.0,
        messages,
      });

      console.log('OpenAI completion created, starting stream...');

      for await (const part of completion) {
        const delta = part.choices?.[0]?.delta?.content ?? "";
        console.log('Received delta:', delta);
        if (delta) {
          // Each token/chunk goes as an SSE 'data:' line
          res.write(`data: ${JSON.stringify({ type: "text", delta })}\n\n`);
        }
      }

      console.log('Stream completed');
      // Signal completion
      res.write(`data: ${JSON.stringify({ type: "done" })}\n\n`);
      clearInterval(heartbeat);
      res.end();
    } catch (err: any) {
      // Make sure we always end the stream with an error message
      const msg = err?.message ?? "Unknown error";
      try {
        res.write(`data: ${JSON.stringify({ type: "error", message: msg })}\n\n`);
      } catch {}
      res.end();
    }
  });
});

