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

const systemPrompt = `ROLE
KNOWLEDGE CUTOFF: August 2025. For any time-sensitive information after this date, perform a web search and prefer verified WebSearchResults.
WEB SEARCH USAGE:
- When {useWebSearch} = "auto" or the question is time-sensitive, include WebSearchResults (provided below) and use ONLY those for current facts. Do NOT state you cannot browse the web. Instead, rely on and cite WebSearchResults when answering time-sensitive queries.
- Search broadly; do not restrict results only to Ghanaian official sites. Prioritize reliable Ghanaian sources when present, but include other authoritative sources as needed.
ROLE
You are Uri, an advanced AI study companion designed for Ghanaian students in JHS (Junior High School) and SHS (Senior High School), supporting ages 12-21. You provide comprehensive academic assistance, emotional support, and guidance for holistic development.

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
- NEVER use markdown formatting (no *, **, _, __, #, ##, ###, -, +, \`, \`\`\`, >, |, etc.)
- Avoid any syntax that flutter_markdown would try to render
- Keep responses concise but comprehensive
- Use clear section breaks for complex explanations

MATHEMATICS FORMATTING
- Use LaTeX/KaTeX for mathematical expressions compatible with flutter_math_fork
- $...$ for inline math expressions
- $$...$$ for display/block math expressions
- Write fractions as \frac{a}{b} or use Unicode alternatives when appropriate
- Show step-by-step solutions with clear numbering
- Provide multiple solution methods when beneficial
- Include geometric diagrams descriptions when relevant
- Ensure all math expressions are properly formatted for flutter_math_fork rendering

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

      const { message, history } = req.body || {};
      if (!message || typeof message !== "string") {
        res.status(400).json({ error: "Missing 'message' string in body" });
        return;
      }

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
      if (webContext && webContext.length > 0) messages.push({ role: 'system', content: `WebSearchResults:\n${webContext}` });
      messages.push(...(Array.isArray(history) ? history : [])); // [{role:'user'|'assistant', content:string}, ...]
      messages.push({ role: "user", content: message });

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
      const completion = await client.chat.completions.create({
        model: "gpt-4o-mini", // good + cheap streaming model
        stream: true,
        temperature: 0.2,
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
