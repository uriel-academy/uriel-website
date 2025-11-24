import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';

// Initialize Anthropic client
let anthropicClient: Anthropic | null = null;

function getAnthropicClient(): Anthropic {
  if (!anthropicClient) {
    const apiKey = functions.config().anthropic?.key;
    if (!apiKey) {
      throw new Error('Anthropic API key not configured');
    }
    anthropicClient = new Anthropic({ apiKey });
  }
  return anthropicClient;
}

// JHS English Curriculum Structure based on NACCA standards
const JHS_ENGLISH_CURRICULUM = {
  'JHS 1': {
    chapters: [
      {
        title: 'Grammar Fundamentals',
        topics: [
          'Parts of Speech: Nouns',
          'Parts of Speech: Pronouns',
          'Parts of Speech: Verbs',
          'Parts of Speech: Adjectives',
          'Parts of Speech: Adverbs',
        ],
      },
      {
        title: 'Reading and Comprehension',
        topics: [
          'Reading Strategies',
          'Understanding Main Ideas',
          'Making Inferences',
          'Context Clues',
          'Reading for Information',
        ],
      },
      {
        title: 'Writing Skills',
        topics: [
          'Sentence Construction',
          'Paragraph Writing',
          'Descriptive Writing',
          'Narrative Writing',
          'Letter Writing Basics',
        ],
      },
      {
        title: 'Vocabulary Building',
        topics: [
          'Word Formation',
          'Synonyms and Antonyms',
          'Prefixes and Suffixes',
          'Idioms and Expressions',
          'Contextual Vocabulary',
        ],
      },
      {
        title: 'Oral Communication',
        topics: [
          'Listening Skills',
          'Speaking with Confidence',
          'Group Discussions',
          'Presentations',
          'Storytelling',
        ],
      },
    ],
  },
  'JHS 2': {
    chapters: [
      {
        title: 'Advanced Grammar',
        topics: [
          'Tenses: Present and Past',
          'Tenses: Future',
          'Active and Passive Voice',
          'Direct and Indirect Speech',
          'Conditionals',
        ],
      },
      {
        title: 'Literature and Poetry',
        topics: [
          'Introduction to Poetry',
          'Literary Devices',
          'African Folktales',
          'Short Story Analysis',
          'Drama Basics',
        ],
      },
      {
        title: 'Essay Writing',
        topics: [
          'Argumentative Essays',
          'Descriptive Essays',
          'Narrative Essays',
          'Expository Essays',
          'Essay Planning and Structure',
        ],
      },
      {
        title: 'Reading Comprehension Advanced',
        topics: [
          'Critical Reading',
          "Author's Purpose",
          'Analyzing Arguments',
          'Comparing Texts',
          'Reading Speed and Efficiency',
        ],
      },
      {
        title: 'Formal Communication',
        topics: [
          'Business Letters',
          'Formal Speeches',
          'Reports and Summaries',
          'Interview Skills',
          'Debate Techniques',
        ],
      },
    ],
  },
  'JHS 3': {
    chapters: [
      {
        title: 'BECE Exam Preparation: Grammar',
        topics: [
          'Comprehensive Grammar Review',
          'Common Grammar Mistakes',
          'Punctuation Mastery',
          'Sentence Types and Structures',
          'Grammar in Context',
        ],
      },
      {
        title: 'BECE Exam Preparation: Comprehension',
        topics: [
          'Advanced Reading Strategies',
          'Answering Comprehension Questions',
          'Time Management',
          'Inference and Deduction',
          'Practice Passages',
        ],
      },
      {
        title: 'BECE Exam Preparation: Essay Writing',
        topics: [
          'BECE Essay Formats',
          'Planning Under Pressure',
          'Introduction and Conclusion Techniques',
          'Common Essay Topics',
          'Improving Your Writing Style',
        ],
      },
      {
        title: 'Literature for BECE',
        topics: [
          'Poetry Analysis for BECE',
          'Prose Comprehension',
          'Drama Interpretation',
          'Literary Terms Review',
          'Practice Questions',
        ],
      },
      {
        title: 'Summary and Letter Writing',
        topics: [
          'Summary Writing Techniques',
          'Letter Writing Formats',
          'Notice and Announcement Writing',
          'Speech Writing',
          'Final Revision Strategies',
        ],
      },
    ],
  },
};

// XP System Configuration
const XP_CONFIG = {
  SECTION_QUESTION: 10, // XP for answering a section question
  CHAPTER_QUESTION: 15, // XP for answering a chapter question
  YEAR_QUESTION: 20, // XP for answering a year-end question
  SECTION_COMPLETE: 50, // XP for completing a section
  CHAPTER_COMPLETE: 200, // XP for completing a chapter
  YEAR_COMPLETE: 1000, // XP for completing a year
  ALL_YEARS_COMPLETE: 5000, // XP for completing all 3 years
  PERFECT_SECTION: 30, // Bonus XP for 100% on section questions
  PERFECT_CHAPTER: 100, // Bonus XP for 100% on chapter questions
  PERFECT_YEAR: 500, // Bonus XP for 100% on year-end questions
};

const GenerateTextbookSchema = z.object({
  year: z.enum(['JHS 1', 'JHS 2', 'JHS 3']),
  batchSize: z.number().min(1).max(5).default(2),
});

/**
 * Generate a complete section with content and questions
 */
async function generateSection(
  year: string,
  chapterTitle: string,
  topicTitle: string,
  chapterIndex: number,
  topicIndex: number,
  anthropic: Anthropic
): Promise<any> {
  const sectionNumber = topicIndex + 1;

  const prompt = `You are creating comprehensive English language textbook content for ${year} students in Ghana (ages 12-15). This is aligned with NACCA BECE curriculum standards.

**Chapter ${chapterIndex + 1}: ${chapterTitle}**
**Section ${sectionNumber}: ${topicTitle}**

Create a complete, engaging section with the following structure:

# ${topicTitle}

## Learning Objectives
[3-5 specific, measurable objectives using action verbs like "identify," "explain," "analyse," "demonstrate"]

## Introduction
[2-3 engaging paragraphs that:
- Connect to students' daily lives in Ghana
- Explain why this topic is important
- Preview what they will learn]

## Main Content
[Break into 3-4 clear subsections with headings. Include:
- Clear explanations in British English
- Relevant examples using Ghanaian context
- Step-by-step guidance
- Key terms in **bold**
- 2-3 "Quick Check" practice activities within the content

VISUAL ENHANCEMENTS (MUST INCLUDE):
• At least ONE Markdown TABLE (for grammar rules, comparisons, word lists, conjugations, etc.)
  Example:
  | Category | Example | Notes |
  |----------|---------|-------|
  | Noun | Accra | Capital city |
  
• ONE ASCII DIAGRAM or visual representation
  Example:
  \`\`\`
  Subject → Verb → Object
     |        |        |
  [Student] [reads] [book]
  \`\`\`
  
• CALLOUT BOXES using blockquotes for tips/warnings
  Example:
  > 💡 **Tip**: Always check subject-verb agreement!
  > ⚠️ **Warning**: Common mistake to avoid
  
• Visual separators (---) between sections
• Bullet points and numbered lists for clarity]

## Worked Examples
[Provide 3 detailed examples in a clear format:
- The problem/task
- Step-by-step solution (use tables or structured format)
- Common mistakes in a callout box
- Tips for success]

## Summary
[Create a visually appealing summary:
- Use bullet points or numbered list
- Include 5-7 key takeaways
- Add a summary table if appropriate]

## Key Vocabulary
[Present vocabulary in a structured table format:

| Term | Definition | Example Sentence |
|------|------------|------------------|
| Term1 | Clear definition | Example in context |
| Term2 | Clear definition | Example in context |

Include 10-15 important terms]

## Section Review Questions
Now create exactly 5 multiple-choice questions that test understanding of this section:

[For each question, provide:
1. Clear question stem
2. Four options (A, B, C, D)
3. Correct answer
4. Brief explanation of why it's correct
5. Difficulty level (easy/medium/hard)]

Format questions as JSON:
{
  "questions": [
    {
      "id": "jhs${year.split(' ')[1]}_ch${chapterIndex + 1}_sec${sectionNumber}_q1",
      "questionText": "...",
      "options": {
        "A": "...",
        "B": "...",
        "C": "...",
        "D": "..."
      },
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy",
      "xpValue": ${XP_CONFIG.SECTION_QUESTION},
      "topic": "${topicTitle}",
      "chapter": "${chapterTitle}",
      "year": "${year}"
    }
  ]
}

Make the content engaging, culturally relevant, and age-appropriate. Use real Ghanaian examples (places, names, situations students can relate to). Write in British English with proper spelling (colour, organisation, etc.).`;

  const message = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 8192,
    temperature: 0.7,
    messages: [{ role: 'user', content: prompt }],
  });

  const content = message.content[0].type === 'text' ? message.content[0].text : '';

  // Extract questions JSON from content
  const questionsMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);
  let questions = [];
  if (questionsMatch) {
    try {
      const questionsData = JSON.parse(questionsMatch[0]);
      questions = questionsData.questions || [];
    } catch (e) {
      console.error('Failed to parse questions JSON:', e);
    }
  }

  return {
    sectionNumber,
    title: topicTitle,
    content,
    questions,
    wordCount: content.split(/\s+/).length,
    estimatedReadingTime: Math.ceil(content.split(/\s+/).length / 200),
    xpReward: XP_CONFIG.SECTION_COMPLETE,
    metadata: {
      year,
      chapter: chapterTitle,
      chapterIndex,
      topicIndex,
      tokensUsed: message.usage.input_tokens + message.usage.output_tokens,
    },
  };
}

/**
 * Generate chapter-end review questions
 */
async function generateChapterQuestions(
  year: string,
  chapterTitle: string,
  topics: string[],
  chapterIndex: number,
  anthropic: Anthropic
): Promise<any[]> {
  const prompt = `Create 20 comprehensive review questions for Chapter ${chapterIndex + 1}: ${chapterTitle} in a ${year} English textbook for Ghanaian students.

Topics covered in this chapter:
${topics.map((t, i) => `${i + 1}. ${t}`).join('\n')}

Create exactly 20 multiple-choice questions that:
- Cover all topics in the chapter
- Progress from easy to difficult
- Test different cognitive levels (recall, understanding, application, analysis)
- Use Ghanaian context and examples
- Are appropriate for BECE preparation

Format as JSON array:
{
  "questions": [
    {
      "id": "jhs${year.split(' ')[1]}_ch${chapterIndex + 1}_review_q1",
      "questionText": "...",
      "options": {
        "A": "...",
        "B": "...",
        "C": "...",
        "D": "..."
      },
      "correctAnswer": "B",
      "explanation": "...",
      "difficulty": "medium",
      "xpValue": ${XP_CONFIG.CHAPTER_QUESTION},
      "topic": "Chapter Review",
      "chapter": "${chapterTitle}",
      "year": "${year}"
    }
  ]
}`;

  const message = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 8192,
    temperature: 0.7,
    messages: [{ role: 'user', content: prompt }],
  });

  const content = message.content[0].type === 'text' ? message.content[0].text : '';
  const questionsMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);

  if (questionsMatch) {
    try {
      const questionsData = JSON.parse(questionsMatch[0]);
      return questionsData.questions || [];
    } catch (e) {
      console.error('Failed to parse chapter questions:', e);
      return [];
    }
  }

  return [];
}

/**
 * Generate year-end final assessment
 */
async function generateYearEndAssessment(
  year: string,
  allChapters: any[],
  anthropic: Anthropic
): Promise<any[]> {
  const chaptersInfo = allChapters
    .map((ch, i) => `Chapter ${i + 1}: ${ch.title} (${ch.topics.length} topics)`)
    .join('\n');

  const prompt = `Create a comprehensive 40-question final assessment for ${year} English textbook for Ghanaian students preparing for BECE.

Chapters covered this year:
${chaptersInfo}

Create exactly 40 multiple-choice questions that:
- Cover all chapters proportionally
- Simulate BECE exam style and difficulty
- Progress from easier to more challenging
- Include grammar, comprehension, vocabulary, and writing questions
- Use authentic Ghanaian contexts
- Prepare students for actual BECE English exam

Format as JSON array with all 40 questions:
{
  "questions": [
    {
      "id": "jhs${year.split(' ')[1]}_final_q1",
      "questionText": "...",
      "options": {
        "A": "...",
        "B": "...",
        "C": "...",
        "D": "..."
      },
      "correctAnswer": "C",
      "explanation": "...",
      "difficulty": "hard",
      "xpValue": ${XP_CONFIG.YEAR_QUESTION},
      "topic": "Year-End Assessment",
      "chapter": "Final Review",
      "year": "${year}"
    }
  ]
}`;

  const message = await anthropic.messages.create({
    model: 'claude-3-5-sonnet-20241022',
    max_tokens: 16384,
    temperature: 0.7,
    messages: [{ role: 'user', content: prompt }],
  });

  const content = message.content[0].type === 'text' ? message.content[0].text : '';
  const questionsMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);

  if (questionsMatch) {
    try {
      const questionsData = JSON.parse(questionsMatch[0]);
      return questionsData.questions || [];
    } catch (e) {
      console.error('Failed to parse year-end questions:', e);
      return [];
    }
  }

  return [];
}

/**
 * Main function to generate complete English textbooks for JHS 1-3
 */
export const generateEnglishTextbooks = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB',
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userRole = userDoc.data()?.role || context.auth.token.role;

    if (!['super_admin', 'teacher', 'school_admin'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const parsed = GenerateTextbookSchema.safeParse(data);
    if (!parsed.success) {
      throw new functions.https.HttpsError('invalid-argument', parsed.error.message);
    }

    const { year, batchSize } = parsed.data;

    try {
      const anthropic = getAnthropicClient();
      const curriculum = JHS_ENGLISH_CURRICULUM[year as keyof typeof JHS_ENGLISH_CURRICULUM];

      // Create textbook document
      const textbookRef = await admin.firestore().collection('textbooks').add({
        subject: 'English',
        year,
        title: `English Language for ${year}`,
        status: 'generating',
        totalChapters: curriculum.chapters.length,
        completedChapters: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        xpConfig: XP_CONFIG,
      });

      // Process chapters
      const generatedChapters = [];

      for (let chIndex = 0; chIndex < curriculum.chapters.length; chIndex++) {
        const chapter = curriculum.chapters[chIndex];
        console.log(`Generating Chapter ${chIndex + 1}: ${chapter.title}`);

        const sections = [];

        // Generate sections in batches
        for (let i = 0; i < chapter.topics.length; i += batchSize) {
          const batch = chapter.topics.slice(i, i + batchSize);

          for (const topic of batch) {
            const topicIndex = chapter.topics.indexOf(topic);
            console.log(`  Generating Section ${topicIndex + 1}: ${topic}`);

            const section = await generateSection(
              year,
              chapter.title,
              topic,
              chIndex,
              topicIndex,
              anthropic
            );

            // Save section to Firestore
            const sectionRef = await admin
              .firestore()
              .collection('textbooks')
              .doc(textbookRef.id)
              .collection('sections')
              .add(section);

            // Save section questions
            for (const question of section.questions) {
              await admin
                .firestore()
                .collection('textbooks')
                .doc(textbookRef.id)
                .collection('questions')
                .add({
                  ...question,
                  sectionId: sectionRef.id,
                  questionType: 'section',
                });
            }

            sections.push({
              ...section,
              id: sectionRef.id,
            });

            // Rate limiting
            await new Promise((resolve) => setTimeout(resolve, 2000));
          }
        }

        // Generate chapter review questions
        console.log(`  Generating Chapter ${chIndex + 1} Review Questions`);
        const chapterQuestions = await generateChapterQuestions(
          year,
          chapter.title,
          chapter.topics,
          chIndex,
          anthropic
        );

        // Save chapter questions
        for (const question of chapterQuestions) {
          await admin
            .firestore()
            .collection('textbooks')
            .doc(textbookRef.id)
            .collection('questions')
            .add({
              ...question,
              chapterIndex: chIndex,
              questionType: 'chapter',
            });
        }

        // Save chapter document
        const chapterRef = await admin
          .firestore()
          .collection('textbooks')
          .doc(textbookRef.id)
          .collection('chapters')
          .add({
            chapterNumber: chIndex + 1,
            title: chapter.title,
            sections: sections.map((s) => ({ id: s.id, title: s.title })),
            totalSections: sections.length,
            totalQuestions: sections.reduce((sum, s) => sum + s.questions.length, 0) + 20,
            xpReward: XP_CONFIG.CHAPTER_COMPLETE,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        generatedChapters.push({
          id: chapterRef.id,
          title: chapter.title,
          sections,
        });

        // Update progress
        await textbookRef.update({
          completedChapters: chIndex + 1,
        });

        await new Promise((resolve) => setTimeout(resolve, 3000));
      }

      // Generate year-end assessment
      console.log('Generating Year-End Assessment');
      const yearEndQuestions = await generateYearEndAssessment(year, curriculum.chapters, anthropic);

      // Save year-end questions
      for (const question of yearEndQuestions) {
        await admin
          .firestore()
          .collection('textbooks')
          .doc(textbookRef.id)
          .collection('questions')
          .add({
            ...question,
            questionType: 'yearEnd',
          });
      }

      // Mark textbook as complete
      await textbookRef.update({
        status: 'published',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        totalSections: generatedChapters.reduce((sum, ch) => sum + ch.sections.length, 0),
        totalQuestions:
          generatedChapters.reduce(
            (sum, ch) => sum + ch.sections.reduce((s, sec) => s + sec.questions.length, 0),
            0
          ) +
          curriculum.chapters.length * 20 +
          40,
      });

      return {
        success: true,
        textbookId: textbookRef.id,
        year,
        chapters: generatedChapters.length,
        sections: generatedChapters.reduce((sum, ch) => sum + ch.sections.length, 0),
        totalQuestions:
          generatedChapters.reduce(
            (sum, ch) => sum + ch.sections.reduce((s, sec) => s + sec.questions.length, 0),
            0
          ) +
          curriculum.chapters.length * 20 +
          40,
      };
    } catch (error: any) {
      console.error('Error generating textbook:', error);
      throw new functions.https.HttpsError('internal', `Generation failed: ${error.message}`);
    }
  });
