/**
 * Admin script to generate English textbooks using Firebase Admin SDK
 * Run with: node generate_textbooks_admin.js
 */

require('dotenv').config();

const admin = require('firebase-admin');
const Anthropic = require('@anthropic-ai/sdk');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'uriel-academy-41fb0'
});

const firestore = admin.firestore();

// Get API key from environment
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;

if (!ANTHROPIC_API_KEY) {
  console.error('\n❌ ERROR: ANTHROPIC_API_KEY environment variable not set!');
  console.error('Please set it with: $env:ANTHROPIC_API_KEY = "your-key-here"\n');
  process.exit(1);
}

console.log(`\n🔑 API Key loaded: ${ANTHROPIC_API_KEY.substring(0, 10)}...${ANTHROPIC_API_KEY.substring(ANTHROPIC_API_KEY.length - 4)}\n`);

// Initialize Claude
const anthropic = new Anthropic({
  apiKey: ANTHROPIC_API_KEY
});

// Import curriculum structure
const JHS_ENGLISH_CURRICULUM = {
  'JHS 1': {
    chapters: [
      {
        title: 'Grammar Fundamentals',
        topics: [
          'Parts of Speech',
          'Basic Tenses',
          'Articles and Determiners',
          'Subject-Verb Agreement',
          'Simple Sentence Structure',
        ],
      },
      {
        title: 'Reading and Comprehension',
        topics: [
          'Finding Main Ideas',
          'Making Inferences',
          'Context Clues',
          'Fact vs Opinion',
          'Story Elements',
        ],
      },
      {
        title: 'Writing Skills',
        topics: [
          'Sentence Writing',
          'Paragraph Structure',
          'Descriptive Writing',
          'Narrative Writing',
          'Writing Process',
        ],
      },
      {
        title: 'Vocabulary Building',
        topics: [
          'Word Formation',
          'Synonyms and Antonyms',
          'Homophones',
          'Common Idioms',
          'Word Families',
        ],
      },
      {
        title: 'Oral Communication',
        topics: [
          'Listening Skills',
          'Speaking Clearly',
          'Group Discussions',
          'Presentations',
          'Telephone Etiquette',
        ],
      },
    ],
  },
  'JHS 2': {
    chapters: [
      {
        title: 'Advanced Grammar',
        topics: [
          'Complex Sentences',
          'Active and Passive Voice',
          'Direct and Indirect Speech',
          'Conditional Sentences',
          'Phrasal Verbs',
        ],
      },
      {
        title: 'Literature and Poetry',
        topics: [
          'Figurative Language',
          'Poetry Analysis',
          'Character Analysis',
          'Theme and Message',
          'Literary Devices',
        ],
      },
      {
        title: 'Essay Writing',
        topics: [
          'Essay Structure',
          'Argumentative Writing',
          'Expository Writing',
          'Editing and Revision',
          'Citations and References',
        ],
      },
      {
        title: 'Reading Comprehension Advanced',
        topics: [
          'Critical Reading',
          'Analysing Arguments',
          'Author\'s Purpose',
          'Text Structure',
          'Comparing Texts',
        ],
      },
      {
        title: 'Formal Communication',
        topics: [
          'Business Letters',
          'Email Writing',
          'Reports',
          'Minutes of Meetings',
          'Formal Presentations',
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

const XP_CONFIG = {
  SECTION_QUESTION: 10,
  SECTION_COMPLETE: 50,
  CHAPTER_QUESTION: 15,
  CHAPTER_COMPLETE: 200,
  YEAR_QUESTION: 20,
  YEAR_COMPLETE: 1000,
  ALL_YEARS_COMPLETE: 5000,
};

/**
 * Generate section content with Claude
 */
async function generateSection(year, chapterNumber, chapterTitle, sectionNumber, topic) {
  console.log(`  📝 Generating: ${topic}...`);
  
  const prompt = `Create comprehensive English Language content for Ghanaian JHS students.

Year: ${year}
Chapter ${chapterNumber}: ${chapterTitle}
Section ${sectionNumber}: ${topic}

Create engaging educational content (800-1200 words) in British English with:

## Learning Objectives
[3-5 specific objectives]

## Introduction
[2-3 engaging paragraphs connecting to Ghana/student life]

## Main Content
[3-4 subsections with:
- Clear explanations
- Ghanaian examples
- Key terms in **bold**
- At least ONE Markdown TABLE
- ONE ASCII DIAGRAM
- CALLOUT BOXES (>) for tips
- Visual separators (---)]

## Worked Examples
[3 detailed examples with step-by-step solutions]

## Summary
[5-7 bullet points]

## Key Vocabulary
[Table with 10-15 terms, definitions, examples]

Then create 5 multiple-choice questions in this JSON format:
{
  "questions": [
    {
      "id": "q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy",
      "xpValue": ${XP_CONFIG.SECTION_QUESTION}
    }
  ]
}`;

  try {
    const response = await anthropic.messages.create({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 4000,
      messages: [{
        role: 'user',
        content: prompt
      }]
    });

    const content = response.content[0].text;
    
    // Extract JSON questions
    const jsonMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    const questions = jsonMatch ? JSON.parse(jsonMatch[0]).questions : [];
    
    // Remove JSON from content
    const markdownContent = content.replace(/\{[\s\S]*"questions"[\s\S]*\}/, '').trim();
    
    return {
      content: markdownContent,
      questions: questions
    };
  } catch (error) {
    console.error(`    ❌ Error generating section: ${error.message}`);
    throw error;
  }
}

/**
 * Generate complete textbook
 */
async function generateTextbook(year) {
  console.log(`\n${'='.repeat(70)}`);
  console.log(`📚 GENERATING: ${year} English Textbook`);
  console.log(`🤖 Using: Claude 3.5 Sonnet`);
  console.log(`⏰ Started: ${new Date().toLocaleTimeString()}`);
  console.log(`${'='.repeat(70)}\n`);

  const curriculum = JHS_ENGLISH_CURRICULUM[year];
  const textbookId = `english_${year.replace(' ', '_').toLowerCase()}`;

  try {
    // Create textbook document
    const textbookRef = firestore.collection('textbooks').doc(textbookId);
    await textbookRef.set({
      id: textbookId,
      subject: 'English',
      year: year,
      title: `Comprehensive English ${year}`,
      description: `Interactive BECE-aligned English textbook for ${year} students`,
      totalChapters: curriculum.chapters.length,
      totalSections: curriculum.chapters.reduce((sum, ch) => sum + ch.topics.length, 0),
      totalQuestions: curriculum.chapters.reduce((sum, ch) => sum + ch.topics.length, 0) * 5 + curriculum.chapters.length * 20 + 40,
      status: 'generating',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Textbook document created: ${textbookId}\n`);

    // Generate chapters and sections
    for (let chIndex = 0; chIndex < curriculum.chapters.length; chIndex++) {
      const chapter = curriculum.chapters[chIndex];
      console.log(`\n📖 Chapter ${chIndex + 1}/${curriculum.chapters.length}: ${chapter.title}`);

      const sections = [];

      // Generate sections
      for (let sIndex = 0; sIndex < chapter.topics.length; sIndex++) {
        const topic = chapter.topics[sIndex];
        
        const sectionData = await generateSection(
          year,
          chIndex + 1,
          chapter.title,
          sIndex + 1,
          topic
        );

        const sectionId = `section_${chIndex + 1}_${sIndex + 1}`;
        
        // Save section
        await textbookRef
          .collection('chapters')
          .doc(`chapter_${chIndex + 1}`)
          .collection('sections')
          .doc(sectionId)
          .set({
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

        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      // Save chapter
      await textbookRef
        .collection('chapters')
        .doc(`chapter_${chIndex + 1}`)
        .set({
          id: `chapter_${chIndex + 1}`,
          chapterNumber: chIndex + 1,
          title: chapter.title,
          sections: sections,
          totalSections: sections.length,
          xpReward: XP_CONFIG.CHAPTER_COMPLETE,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`  ✅ Chapter ${chIndex + 1} complete!\n`);
    }

    // Mark as published
    await textbookRef.update({
      status: 'published',
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`\n${'='.repeat(70)}`);
    console.log(`✅ ${year} TEXTBOOK GENERATION COMPLETE!`);
    console.log(`⏰ Finished: ${new Date().toLocaleTimeString()}`);
    console.log(`${'='.repeat(70)}\n`);

    return { success: true, textbookId, year };
  } catch (error) {
    console.error(`\n❌ Error generating ${year}:`, error);
    
    // Mark as failed
    await firestore.collection('textbooks').doc(textbookId).update({
      status: 'failed',
      error: error.message,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: false, year, error: error.message };
  }
}

/**
 * Main execution
 */
async function main() {
  console.log('\n' + '🎓'.repeat(35));
  console.log('📚 ENGLISH TEXTBOOK GENERATION - ALL YEARS');
  console.log('🎓'.repeat(35));
  console.log(`\n⏰ Started: ${new Date().toLocaleString()}`);
  console.log(`🤖 Model: Claude 3.5 Sonnet`);
  console.log(`📍 Years: JHS 1, JHS 2, JHS 3`);
  console.log(`⏱️  Estimated time: 20-30 minutes total\n`);

  const results = [];

  for (const year of ['JHS 1', 'JHS 2', 'JHS 3']) {
    const result = await generateTextbook(year);
    results.push(result);

    if (year !== 'JHS 3') {
      console.log(`\n⏸️  Waiting 5 seconds before next year...\n`);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('📊 GENERATION SUMMARY');
  console.log('='.repeat(70) + '\n');

  results.forEach(({ year, success, error }) => {
    if (success) {
      console.log(`✅ ${year}: SUCCESS`);
    } else {
      console.log(`❌ ${year}: FAILED - ${error}`);
    }
  });

  const successCount = results.filter(r => r.success).length;
  console.log(`\n🎯 Total: ${successCount}/3 textbooks generated`);
  console.log(`⏰ Completed: ${new Date().toLocaleString()}\n`);

  process.exit(successCount === 3 ? 0 : 1);
}

main().catch(error => {
  console.error('\n💥 FATAL ERROR:', error);
  process.exit(1);
});
