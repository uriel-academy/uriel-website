/**
 * Generate only JHS 3 textbook with all questions
 */

require('dotenv').config();

const admin = require('firebase-admin');
const OpenAI = require('openai');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const firestore = admin.firestore();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const JHS_3_CURRICULUM = {
  chapters: [
    {
      title: 'BECE Exam Preparation: Grammar',
      topics: ['Comprehensive Grammar Review', 'Common Grammar Mistakes', 'Punctuation Mastery', 'Sentence Types and Structures', 'Grammar in Context'],
    },
    {
      title: 'BECE Exam Preparation: Comprehension',
      topics: ['Advanced Reading Strategies', 'Answering Comprehension Questions', 'Time Management', 'Inference and Deduction', 'Practice Passages'],
    },
    {
      title: 'BECE Exam Preparation: Essay Writing',
      topics: ['BECE Essay Formats', 'Planning Under Pressure', 'Introduction and Conclusion Techniques', 'Common Essay Topics', 'Improving Your Writing Style'],
    },
    {
      title: 'Literature for BECE',
      topics: ['Poetry Analysis for BECE', 'Prose Comprehension', 'Drama Interpretation', 'Literary Terms Review', 'Practice Questions'],
    },
    {
      title: 'Summary and Letter Writing',
      topics: ['Summary Writing Techniques', 'Letter Writing Formats', 'Notice and Announcement Writing', 'Speech Writing', 'Final Revision Strategies'],
    },
  ],
};

const XP_CONFIG = { SECTION_QUESTION: 10, SECTION_COMPLETE: 50, CHAPTER_QUESTION: 15, CHAPTER_COMPLETE: 200, YEAR_QUESTION: 20, YEAR_COMPLETE: 1000 };

async function generateSection(chapterNumber, chapterTitle, sectionNumber, topic) {
  console.log(`  📝 Generating: ${topic}...`);
  
  const prompt = `Create comprehensive English Language content for Ghanaian JHS 3 students preparing for BECE.

Chapter ${chapterNumber}: ${chapterTitle}
Section ${sectionNumber}: ${topic}

Create 800-1200 words in British English with tables, diagrams, callout boxes, and examples.

At the very end, create exactly 5 multiple-choice questions. You MUST wrap them in a JSON code block like this:

\`\`\`json
{
  "questions": [
    {
      "id": "q1",
      "questionText": "What is the main purpose of...",
      "options": {
        "A": "First option",
        "B": "Second option",
        "C": "Third option",
        "D": "Fourth option"
      },
      "correctAnswer": "A",
      "explanation": "Brief explanation of why A is correct",
      "difficulty": "easy",
      "xpValue": 10
    }
  ]
}
\`\`\`

Make all 5 questions BECE-aligned and culturally relevant to Ghana.`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    temperature: 0.7,
    max_tokens: 3500
  });

  const content = response.choices[0].message.content;
  
  // Try multiple extraction patterns
  let questions = [];
  
  // Pattern 1: JSON in code block
  let jsonMatch = content.match(/```json\s*(\{[\s\S]*?\})\s*```/);
  if (jsonMatch) {
    try {
      const parsed = JSON.parse(jsonMatch[1]);
      questions = parsed.questions || [];
    } catch (e) {
      console.log(`    ⚠️  Failed to parse JSON from code block: ${e.message}`);
    }
  }
  
  // Pattern 2: Raw JSON object
  if (questions.length === 0) {
    jsonMatch = content.match(/\{\s*"questions"\s*:\s*\[[\s\S]*?\]\s*\}/);
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0]);
        questions = parsed.questions || [];
      } catch (e) {
        console.log(`    ⚠️  Failed to parse raw JSON: ${e.message}`);
      }
    }
  }
  
  // Remove JSON from content
  const markdownContent = content
    .replace(/```json[\s\S]*?```/, '')
    .replace(/\{\s*"questions"\s*:\s*\[[\s\S]*?\]\s*\}/, '')
    .trim();
  
  if (questions.length === 0) {
    console.log(`    ⚠️  Warning: No questions extracted, saving content only`);
  }
  
  return { content: markdownContent, questions };
}

async function generateChapterReview(chapterNumber, chapterTitle, topics) {
  console.log(`  📋 Generating Chapter ${chapterNumber} Review (20 questions)...`);
  
  const prompt = `Create 20 comprehensive BECE-style review questions for:
Chapter ${chapterNumber}: ${chapterTitle}
Topics: ${topics.join(', ')}

Mix of 6 easy, 8 medium, 6 hard questions. Return them in a JSON code block:

\`\`\`json
{
  "questions": [
    {
      "id": "ch${chapterNumber}_q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy",
      "xpValue": 15
    }
  ]
}
\`\`\`

Create all 20 questions with Ghanaian contexts and BECE standards.`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    temperature: 0.7,
    max_tokens: 5000
  });

  const content = response.choices[0].message.content;
  
  // Extract from code block or raw JSON
  let jsonMatch = content.match(/```json\s*(\{[\s\S]*?\})\s*```/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[1]).questions || [];
    } catch (e) {
      console.log(`    ⚠️  JSON parse error: ${e.message}`);
    }
  }
  
  jsonMatch = content.match(/\{\s*"questions"\s*:\s*\[[\s\S]*?\]\s*\}/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[0]).questions || [];
    } catch (e) {
      console.log(`    ⚠️  JSON parse error: ${e.message}`);
    }
  }
  
  console.log(`    ⚠️  Failed to extract chapter review questions`);
  return [];
}

async function generateYearEndAssessment() {
  console.log(`\n📝 Generating Year-End BECE Assessment (40 questions)...`);
  
  const prompt = `Create 40 comprehensive BECE final exam questions covering all JHS 3 English topics including:
- Grammar and punctuation
- Reading comprehension
- Essay writing
- Literature (poetry, prose, drama)
- Summary and letter writing

Mix: 12 easy, 16 medium, 12 hard. British English. Return in JSON code block:

\`\`\`json
{
  "questions": [
    {
      "id": "year_q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "medium",
      "xpValue": 20
    }
  ]
}
\`\`\`

Create all 40 questions with Ghanaian examples and BECE exam format.`;

  const response = await openai.chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: prompt }],
    temperature: 0.7,
    max_tokens: 10000
  });

  const content = response.choices[0].message.content;
  
  // Extract from code block or raw JSON
  let jsonMatch = content.match(/```json\s*(\{[\s\S]*?\})\s*```/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[1]).questions || [];
    } catch (e) {
      console.log(`    ⚠️  JSON parse error: ${e.message}`);
    }
  }
  
  jsonMatch = content.match(/\{\s*"questions"\s*:\s*\[[\s\S]*?\]\s*\}/);
  if (jsonMatch) {
    try {
      return JSON.parse(jsonMatch[0]).questions || [];
    } catch (e) {
      console.log(`    ⚠️  JSON parse error: ${e.message}`);
    }
  }
  
  console.log(`    ⚠️  Failed to extract year-end assessment questions`);
  return [];
}

async function main() {
  console.log('\n📚 GENERATING JHS 3 ENGLISH TEXTBOOK\n');
  
  const textbookId = 'english_jhs_3';
  const textbookRef = firestore.collection('textbooks').doc(textbookId);
  
  await textbookRef.set({
    id: textbookId,
    subject: 'English',
    year: 'JHS 3',
    title: 'Comprehensive English JHS 3',
    description: 'Interactive BECE-aligned English textbook for JHS 3 students',
    totalChapters: 5,
    totalSections: 25,
    totalQuestions: 265,
    status: 'generating',
    generatedBy: 'OpenAI GPT-4o',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  for (let chIndex = 0; chIndex < JHS_3_CURRICULUM.chapters.length; chIndex++) {
    const chapter = JHS_3_CURRICULUM.chapters[chIndex];
    console.log(`\n📖 Chapter ${chIndex + 1}/5: ${chapter.title}`);

    const sections = [];

    for (let sIndex = 0; sIndex < chapter.topics.length; sIndex++) {
      const topic = chapter.topics[sIndex];
      const sectionData = await generateSection(chIndex + 1, chapter.title, sIndex + 1, topic);
      const sectionId = `section_${chIndex + 1}_${sIndex + 1}`;
      
      await textbookRef.collection('chapters').doc(`chapter_${chIndex + 1}`).collection('sections').doc(sectionId).set({
        id: sectionId,
        chapterNumber: chIndex + 1,
        sectionNumber: sIndex + 1,
        title: topic,
        content: sectionData.content,
        questions: sectionData.questions,
        xpReward: XP_CONFIG.SECTION_COMPLETE,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      sections.push({ id: sectionId, title: topic, questionCount: sectionData.questions.length });
      console.log(`    ✅ Saved: ${topic} (${sectionData.questions.length} questions)`);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    const chapterReview = await generateChapterReview(chIndex + 1, chapter.title, chapter.topics);
    await textbookRef.collection('chapters').doc(`chapter_${chIndex + 1}`).collection('questions').doc('chapter_review').set({
      type: 'chapter_review',
      chapterNumber: chIndex + 1,
      questions: chapterReview,
      totalQuestions: chapterReview.length,
      xpReward: XP_CONFIG.CHAPTER_COMPLETE,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`    ✅ Chapter Review: ${chapterReview.length} questions saved`);

    await textbookRef.collection('chapters').doc(`chapter_${chIndex + 1}`).set({
      id: `chapter_${chIndex + 1}`,
      chapterNumber: chIndex + 1,
      title: chapter.title,
      sections,
      totalSections: sections.length,
      xpReward: XP_CONFIG.CHAPTER_COMPLETE,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`  ✅ Chapter ${chIndex + 1} complete!\n`);
  }

  const yearEndQuestions = await generateYearEndAssessment();
  await textbookRef.collection('assessments').doc('year_end').set({
    type: 'year_end_assessment',
    year: 'JHS 3',
    questions: yearEndQuestions,
    totalQuestions: yearEndQuestions.length,
    xpReward: XP_CONFIG.YEAR_COMPLETE,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`  ✅ Year-End Assessment: ${yearEndQuestions.length} questions saved\n`);

  await textbookRef.update({
    status: 'published',
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('✅ JHS 3 TEXTBOOK GENERATION COMPLETE!\n');
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Error:', error);
  process.exit(1);
});
