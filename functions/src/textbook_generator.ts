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

// Schema for textbook content generation
const GenerateContentSchema = z.object({
  subject: z.string().min(1).max(100),
  topic: z.string().min(1).max(300),
  syllabusReference: z.string().optional(),
  grade: z.enum(['BECE', 'WASSCE', 'JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3']).default('BECE'),
  contentType: z.enum(['full_lesson', 'summary', 'practice_questions', 'worked_examples']).default('full_lesson'),
  language: z.enum(['en', 'tw', 'ee', 'ga']).default('en'),
});

const GenerateChapterSchema = z.object({
  subject: z.string().min(1).max(100),
  chapterTitle: z.string().min(1).max(300),
  topics: z.array(z.object({
    title: z.string(),
    syllabusRef: z.string().optional(),
  })),
  grade: z.enum(['BECE', 'WASSCE', 'JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3']).default('BECE'),
});

const BulkGenerateSchema = z.object({
  subject: z.string().min(1).max(100),
  topics: z.array(z.object({
    title: z.string(),
    syllabusRef: z.string().optional(),
  })),
  grade: z.enum(['BECE', 'WASSCE', 'JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3']).default('BECE'),
  batchSize: z.number().min(1).max(10).default(5),
});

// System prompt for educational content generation
const EDUCATION_SYSTEM_PROMPT = `You are an expert educational content creator specializing in creating comprehensive textbook materials for Ghanaian Basic Education Certificate Examination (BECE) and West African Senior School Certificate Examination (WASSCE) students.

Your content must:
- Align with NACCA (National Council for Curriculum and Assessment) standards for Ghana
- Be age-appropriate for the specified grade level (JHS students ages 12-15, SHS students ages 15-18)
- Include clear explanations with local/Ghanaian context where relevant
- Provide practical examples students can relate to
- Follow proper academic structure
- Be accurate and factually correct
- Use British English spelling and grammar
- Include cultural sensitivity for diverse Ghanaian backgrounds

Content Structure Guidelines:
1. Learning objectives should be specific, measurable, and aligned with curriculum
2. Explanations should be clear, progressive, and build upon prior knowledge
3. Examples should be practical and relatable to Ghanaian students
4. Practice questions should vary in difficulty and test different cognitive levels
5. Summaries should reinforce key concepts without introducing new information`;

/**
 * Generate textbook content for a single topic using Claude AI
 */
export const generateTextbookContent = functions
  .region('us-central1')
  .runWith({ 
    timeoutSeconds: 540, // 9 minutes for complex content
    memory: '1GB' 
  })
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Verify user has admin privileges
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    const userRole = userData?.role || context.auth.token.role;

    if (!['super_admin', 'teacher', 'school_admin'].includes(userRole)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only administrators and teachers can generate textbook content'
      );
    }

    // Validate input
    const parsed = GenerateContentSchema.safeParse(data);
    if (!parsed.success) {
      throw new functions.https.HttpsError('invalid-argument', parsed.error.message);
    }

    const { subject, topic, syllabusReference, grade, contentType, language } = parsed.data;

    try {
      const anthropic = getAnthropicClient();

      // Build content generation prompt based on content type
      let userPrompt = '';

      if (contentType === 'full_lesson') {
        userPrompt = `Create comprehensive study material for ${grade} ${subject}

**Topic**: ${topic}

**Syllabus Reference**: ${syllabusReference || 'NACCA Standard Curriculum'}

**Required Structure**:

1. **Learning Objectives** (3-5 specific, measurable objectives aligned with Bloom's Taxonomy)

2. **Introduction** (2-3 paragraphs)
   - Hook the student's interest
   - Connect to prior knowledge
   - Relate to everyday life in Ghana

3. **Main Content** (Detailed explanation broken into clear subsections)
   - Use descriptive headings for each subsection
   - Define all key terms in context
   - Provide step-by-step explanations
   - Include Ghanaian/local context examples
   - Use diagrams descriptions where visual aids would help

4. **Worked Examples** (3-5 detailed examples with full solutions)
   - Show complete working with explanations
   - Use diverse problem types
   - Include common mistakes to avoid

5. **Key Terms & Definitions** (Glossary format)
   - Alphabetically ordered
   - Clear, concise definitions
   - Include pronunciation guides if needed

6. **Practice Questions** (15 questions total)
   - 5 Easy multiple choice (A-D format with distractors)
   - 5 Medium difficulty short answer
   - 5 Challenging essay/problem-solving questions
   - Include marking scheme/answer key at the end

7. **Summary** (Bullet points of main concepts)
   - 5-10 key takeaways
   - Reinforce learning objectives

8. **Real-World Applications** (2-3 paragraphs)
   - How this topic relates to everyday life in Ghana
   - Career connections
   - Further exploration suggestions

Format the content in clean Markdown with proper headings (## for sections, ### for subsections), bullet points, and numbered lists. Use **bold** for key terms on first use.`;
      } else if (contentType === 'summary') {
        userPrompt = `Create a concise study summary for ${grade} ${subject} - ${topic}

Include:
1. Key Concepts (bullet points)
2. Important Formulas/Definitions (if applicable)
3. Quick Review Questions (5 questions with answers)
4. Memory Aids/Mnemonics for difficult concepts

Keep it concise but comprehensive - suitable for quick revision.`;
      } else if (contentType === 'practice_questions') {
        userPrompt = `Create practice questions for ${grade} ${subject} - ${topic}

Generate 20 questions total:
- 10 Multiple choice (BECE/WASSCE format)
- 5 Short answer questions
- 5 Essay/long-form questions

Include:
- Clear question stems
- Appropriate difficulty progression
- Comprehensive marking scheme
- Model answers for essay questions

Align with ${syllabusReference || 'NACCA'} curriculum standards.`;
      } else if (contentType === 'worked_examples') {
        userPrompt = `Create worked examples for ${grade} ${subject} - ${topic}

Provide 5 detailed worked examples that:
- Progress from simple to complex
- Show complete step-by-step solutions
- Explain the reasoning at each step
- Highlight common mistakes
- Include tips and tricks

Make examples relevant to Ghanaian students.`;
      }

      // Add language instruction if not English
      if (language !== 'en') {
        const languageNames: Record<string, string> = {
          tw: 'Twi (Akan)',
          ee: 'Ewe',
          ga: 'Ga',
        };
        userPrompt += `\n\n**IMPORTANT**: Generate all content in ${languageNames[language]}. Use proper ${languageNames[language]} terminology and maintain cultural appropriateness.`;
      }

      // Call Claude API
      const message = await anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 8192,
        temperature: 0.7,
        system: EDUCATION_SYSTEM_PROMPT,
        messages: [{
          role: 'user',
          content: userPrompt,
        }],
      });

      const content = message.content[0].type === 'text' ? message.content[0].text : '';

      if (!content) {
        throw new Error('No content generated from Claude API');
      }

      // Calculate metadata
      const wordCount = content.split(/\s+/).length;
      const estimatedReadingTime = Math.ceil(wordCount / 200); // Average reading speed

      // Save generated content to Firestore
      const docRef = await admin.firestore().collection('textbook_content').add({
        subject,
        topic,
        content,
        syllabusReference: syllabusReference || null,
        grade,
        contentType,
        language,
        wordCount,
        estimatedReadingTime,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: context.auth.uid,
        model: 'claude-3-5-sonnet-20241022',
        status: 'draft', // Requires review before publishing
        metadata: {
          apiVersion: 'anthropic-2023-06-01',
          tokensUsed: message.usage.input_tokens + message.usage.output_tokens,
          inputTokens: message.usage.input_tokens,
          outputTokens: message.usage.output_tokens,
        },
      });

      // Log the generation activity
      await admin.firestore().collection('auditLogs').add({
        action: 'textbook_content_generated',
        performedBy: context.auth.uid,
        documentId: docRef.id,
        details: {
          subject,
          topic,
          grade,
          contentType,
          wordCount,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        id: docRef.id,
        content,
        metadata: {
          subject,
          topic,
          grade,
          contentType,
          wordCount,
          estimatedReadingTime,
          tokensUsed: message.usage.input_tokens + message.usage.output_tokens,
        },
      };
    } catch (error: any) {
      console.error('Error generating textbook content:', error);
      
      // Handle specific Anthropic API errors
      if (error.status === 429) {
        throw new functions.https.HttpsError('resource-exhausted', 'API rate limit exceeded. Please try again later.');
      } else if (error.status === 401) {
        throw new functions.https.HttpsError('internal', 'API authentication failed. Please contact administrator.');
      }
      
      throw new functions.https.HttpsError('internal', `Failed to generate content: ${error.message}`);
    }
  });

/**
 * Generate an entire chapter with multiple topics
 */
export const generateChapter = functions
  .region('us-central1')
  .runWith({ 
    timeoutSeconds: 540,
    memory: '2GB' 
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    const userRole = userData?.role || context.auth.token.role;

    if (!['super_admin', 'teacher', 'school_admin'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
    }

    const parsed = GenerateChapterSchema.safeParse(data);
    if (!parsed.success) {
      throw new functions.https.HttpsError('invalid-argument', parsed.error.message);
    }

    const { subject, chapterTitle, topics, grade } = parsed.data;

    try {
      const generatedSections = [];

      // Generate content for each topic sequentially (to avoid rate limits)
      for (const topic of topics) {
        const result = await generateTextbookContent.run({
          subject,
          topic: topic.title,
          syllabusReference: topic.syllabusRef,
          grade,
          contentType: 'full_lesson',
          language: 'en',
        }, context);

        generatedSections.push({
          topicTitle: topic.title,
          contentId: result.data.id,
          wordCount: result.data.metadata.wordCount,
        });

        // Rate limiting: wait 2 seconds between requests
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      // Create chapter document
      const chapterDoc = await admin.firestore().collection('textbook_chapters').add({
        subject,
        title: chapterTitle,
        grade,
        sections: generatedSections,
        totalSections: generatedSections.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        status: 'draft',
      });

      return {
        success: true,
        chapterId: chapterDoc.id,
        sections: generatedSections,
        totalSections: generatedSections.length,
      };
    } catch (error: any) {
      console.error('Error generating chapter:', error);
      throw new functions.https.HttpsError('internal', `Failed to generate chapter: ${error.message}`);
    }
  });

/**
 * Bulk generate content for multiple topics (queued processing)
 */
export const bulkGenerateContent = functions
  .region('us-central1')
  .runWith({ 
    timeoutSeconds: 540,
    memory: '2GB' 
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    const userRole = userData?.role || context.auth.token.role;

    if (!['super_admin', 'teacher', 'school_admin'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
    }

    const parsed = BulkGenerateSchema.safeParse(data);
    if (!parsed.success) {
      throw new functions.https.HttpsError('invalid-argument', parsed.error.message);
    }

    const { subject, topics, grade, batchSize } = parsed.data;

    try {
      // Create a batch job document
      const batchJobRef = await admin.firestore().collection('textbook_generation_jobs').add({
        subject,
        grade,
        topics,
        totalTopics: topics.length,
        processedTopics: 0,
        status: 'processing',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
        results: [],
      });

      // Process topics in batches
      const results = [];
      for (let i = 0; i < topics.length; i += batchSize) {
        const batch = topics.slice(i, i + batchSize);

        for (const topic of batch) {
          try {
            const result = await generateTextbookContent.run({
              subject,
              topic: topic.title,
              syllabusReference: topic.syllabusRef,
              grade,
              contentType: 'full_lesson',
              language: 'en',
            }, context);

            results.push({
              topicTitle: topic.title,
              contentId: result.data.id,
              status: 'success',
              wordCount: result.data.metadata.wordCount,
            });

            // Update job progress
            await batchJobRef.update({
              processedTopics: admin.firestore.FieldValue.increment(1),
              results: admin.firestore.FieldValue.arrayUnion({
                topicTitle: topic.title,
                contentId: result.data.id,
                status: 'success',
              }),
            });

            // Rate limiting
            await new Promise(resolve => setTimeout(resolve, 2000));
          } catch (error: any) {
            console.error(`Failed to generate content for ${topic.title}:`, error);
            results.push({
              topicTitle: topic.title,
              status: 'failed',
              error: error.message,
            });

            await batchJobRef.update({
              processedTopics: admin.firestore.FieldValue.increment(1),
              results: admin.firestore.FieldValue.arrayUnion({
                topicTitle: topic.title,
                status: 'failed',
                error: error.message,
              }),
            });
          }
        }
      }

      // Mark job as completed
      await batchJobRef.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        jobId: batchJobRef.id,
        totalTopics: topics.length,
        successfulTopics: results.filter(r => r.status === 'success').length,
        failedTopics: results.filter(r => r.status === 'failed').length,
        results,
      };
    } catch (error: any) {
      console.error('Error in bulk generation:', error);
      throw new functions.https.HttpsError('internal', `Bulk generation failed: ${error.message}`);
    }
  });

/**
 * Publish textbook content (move from draft to published)
 */
export const publishTextbookContent = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    const userRole = userData?.role || context.auth.token.role;

    if (!['super_admin', 'school_admin'].includes(userRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can publish content');
    }

    const { contentId } = data;
    if (!contentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Content ID required');
    }

    try {
      await admin.firestore().collection('textbook_content').doc(contentId).update({
        status: 'published',
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        publishedBy: context.auth.uid,
      });

      return { success: true, contentId };
    } catch (error: any) {
      throw new functions.https.HttpsError('internal', `Failed to publish content: ${error.message}`);
    }
  });
