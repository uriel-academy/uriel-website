/**
 * Generate Social Studies and RME Textbooks for JHS 1-3
 * Using OpenAI GPT-4o with comprehensive content, images, and assessments
 * 
 * Run with: node generate_social_rme_textbooks.js
 * 
 * Resume from specific point (if interrupted):
 *   node generate_social_rme_textbooks.js --resume social_studies --year "JHS 1" --chapter 1 --section 3
 *   node generate_social_rme_textbooks.js --resume rme --year "JHS 2"
 */

require('dotenv').config();

const admin = require('firebase-admin');
const OpenAI = require('openai');
const fs = require('fs');
const path = require('path');

// ========================= RETRY CONFIGURATION =========================
const RETRY_CONFIG = {
  maxRetries: 5,
  initialDelay: 5000,     // 5 seconds
  maxDelay: 120000,       // 2 minutes max
  backoffMultiplier: 2,
};

// Parse command line arguments for resume functionality
function parseResumeArgs() {
  const args = process.argv.slice(2);
  const resumeConfig = {
    enabled: false,
    subject: null,
    year: null,
    chapter: null,
    section: null,
  };
  
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--resume' && args[i + 1]) {
      resumeConfig.enabled = true;
      resumeConfig.subject = args[i + 1].toLowerCase().replace('_', ' ');
      i++;
    } else if (args[i] === '--year' && args[i + 1]) {
      resumeConfig.year = args[i + 1];
      i++;
    } else if (args[i] === '--chapter' && args[i + 1]) {
      resumeConfig.chapter = parseInt(args[i + 1]);
      i++;
    } else if (args[i] === '--section' && args[i + 1]) {
      resumeConfig.section = parseInt(args[i + 1]);
      i++;
    }
  }
  
  return resumeConfig;
}

const RESUME_CONFIG = parseResumeArgs();

/**
 * Sleep/delay utility
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry wrapper with exponential backoff
 */
async function withRetry(fn, operationName, retryConfig = RETRY_CONFIG) {
  let lastError;
  let delay = retryConfig.initialDelay;
  
  for (let attempt = 1; attempt <= retryConfig.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      const isConnectionError = 
        error.code === 'ENOTFOUND' ||
        error.code === 'ECONNRESET' ||
        error.code === 'ETIMEDOUT' ||
        error.code === 'ECONNREFUSED' ||
        error.message?.includes('Connection error') ||
        error.message?.includes('fetch failed') ||
        error.message?.includes('network') ||
        error.cause?.code === 'ENOTFOUND';
      
      if (!isConnectionError && attempt === retryConfig.maxRetries) {
        throw error;
      }
      
      if (attempt < retryConfig.maxRetries) {
        console.log(`    ⚠️ ${operationName} failed (attempt ${attempt}/${retryConfig.maxRetries}): ${error.message}`);
        console.log(`    ⏳ Retrying in ${Math.round(delay / 1000)} seconds...`);
        await sleep(delay);
        delay = Math.min(delay * retryConfig.backoffMultiplier, retryConfig.maxDelay);
      }
    }
  }
  
  throw lastError;
}

/**
 * Check if section already exists in Firestore (for resume)
 */
async function sectionExists(textbookId, chapterNum, sectionNum) {
  const sectionId = `section_${chapterNum}_${sectionNum}`;
  const doc = await firestore
    .collection('textbooks')
    .doc(textbookId)
    .collection('chapters')
    .doc(`chapter_${chapterNum}`)
    .collection('sections')
    .doc(sectionId)
    .get();
  return doc.exists;
}

/**
 * Check if chapter review exists in Firestore (for resume)
 */
async function chapterReviewExists(textbookId, chapterNum) {
  const doc = await firestore
    .collection('textbooks')
    .doc(textbookId)
    .collection('chapters')
    .doc(`chapter_${chapterNum}`)
    .collection('questions')
    .doc('chapter_review')
    .get();
  return doc.exists;
}

/**
 * Check if year-end assessment exists in Firestore (for resume)
 */
async function yearEndAssessmentExists(textbookId) {
  const doc = await firestore
    .collection('textbooks')
    .doc(textbookId)
    .collection('assessments')
    .doc('year_end')
    .get();
  return doc.exists;
}

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const firestore = admin.firestore();

// Get API key from environment
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY || OPENAI_API_KEY === 'your-openai-api-key-here') {
  console.error('\n❌ ERROR: OPENAI_API_KEY environment variable not set!');
  console.error('Please add it to the .env file\n');
  process.exit(1);
}

console.log(`\n🔑 OpenAI API Key loaded: ${OPENAI_API_KEY.substring(0, 10)}...${OPENAI_API_KEY.substring(OPENAI_API_KEY.length - 4)}\n`);

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: OPENAI_API_KEY
});

// ========================= CURRICULUM DEFINITIONS =========================

/**
 * Social Studies Curriculum - NaCCA aligned for Ghana JHS
 * Based on the BECE Social Studies meta pack
 */
const SOCIAL_STUDIES_CURRICULUM = {
  'JHS 1': {
    chapters: [
      {
        title: 'The Environment',
        topics: [
          'Our Physical Environment',
          'Components of the Environment',
          'Human Activities and the Environment',
          'Environmental Conservation',
          'Sustainable Development in Ghana',
        ],
      },
      {
        title: 'All About Ghana',
        topics: [
          'Location and Size of Ghana',
          'Ethnic Groups in Ghana',
          'Ghana\'s Independence History',
          'Symbols of Ghana (Flag, Coat of Arms, Anthem)',
          'Regions and Capitals of Ghana',
        ],
      },
      {
        title: 'Government and Leadership',
        topics: [
          'What is Government?',
          'Types of Government',
          'Democracy in Ghana',
          'Local Government in Ghana',
          'Good Citizenship',
        ],
      },
      {
        title: 'Family and Social Life',
        topics: [
          'The Family as a Social Unit',
          'Types of Family Systems in Ghana',
          'Roles and Responsibilities in the Family',
          'Marriage and Family Life',
          'Conflict Resolution in the Family',
        ],
      },
      {
        title: 'Economic Life',
        topics: [
          'Basic Economic Concepts',
          'Types of Economic Activities',
          'Agriculture in Ghana',
          'Trade and Commerce',
          'Money and Banking Basics',
        ],
      },
    ],
  },
  'JHS 2': {
    chapters: [
      {
        title: 'Ghana and Her Neighbours',
        topics: [
          'Countries Bordering Ghana',
          'ECOWAS and Regional Cooperation',
          'Trade Relations with Neighbours',
          'Cultural Similarities and Differences',
          'Border Issues and Solutions',
        ],
      },
      {
        title: 'Population and Development',
        topics: [
          'Population Distribution in Ghana',
          'Census and Its Importance',
          'Population Growth and Challenges',
          'Migration in Ghana',
          'Urbanization and Development',
        ],
      },
      {
        title: 'Resources of Ghana',
        topics: [
          'Natural Resources of Ghana',
          'Mineral Resources (Gold, Bauxite, Oil)',
          'Forest Resources',
          'Water Resources',
          'Human Resources and Development',
        ],
      },
      {
        title: 'Social Issues and Solutions',
        topics: [
          'Poverty and Its Effects',
          'Child Labour and Child Rights',
          'Adolescent Reproductive Health',
          'Drug Abuse and Prevention',
          'HIV/AIDS Awareness',
        ],
      },
      {
        title: 'Rights and Responsibilities',
        topics: [
          'Human Rights',
          'Rights of Children',
          'Rights of Women',
          'Civic Responsibilities',
          'Rule of Law in Ghana',
        ],
      },
    ],
  },
  'JHS 3': {
    chapters: [
      {
        title: 'BECE Prep: Ghana\'s Political History',
        topics: [
          'Pre-Colonial Ghana',
          'Colonial Rule and Its Effects',
          'The Struggle for Independence',
          'Ghana\'s First Republic',
          'Military Interventions and Return to Democracy',
        ],
      },
      {
        title: 'BECE Prep: Ghana\'s Constitution and Government',
        topics: [
          'The 1992 Constitution',
          'Arms of Government (Executive, Legislature, Judiciary)',
          'Separation of Powers',
          'Decentralization and Local Government',
          'Electoral Commission and Elections',
        ],
      },
      {
        title: 'BECE Prep: International Relations',
        topics: [
          'Ghana and the United Nations',
          'Ghana and the African Union',
          'International Trade and Globalization',
          'Foreign Policy of Ghana',
          'International Cooperation for Development',
        ],
      },
      {
        title: 'BECE Prep: Contemporary Issues',
        topics: [
          'Environmental Degradation (Galamsey, Deforestation)',
          'Youth Unemployment',
          'Corruption and Anti-Corruption Measures',
          'Gender Equality',
          'National Development Planning',
        ],
      },
      {
        title: 'BECE Revision and Practice',
        topics: [
          'Map Reading and Interpretation',
          'Analysing Social Studies Questions',
          'Essay Writing Techniques',
          'Time Management in Exams',
          'Full BECE Practice Tests',
        ],
      },
    ],
  },
};

/**
 * Religious and Moral Education (RME) Curriculum
 * Based on the BECE RME meta pack - Multi-faith approach
 */
const RME_CURRICULUM = {
  'JHS 1': {
    chapters: [
      {
        title: 'Religion and Life',
        topics: [
          'What is Religion?',
          'Major Religions in Ghana (Christianity, Islam, Traditional)',
          'The Importance of Religion in Society',
          'Religious Tolerance and Peaceful Coexistence',
          'Sacred Places and Objects',
        ],
      },
      {
        title: 'God and Creation',
        topics: [
          'Beliefs About God in Different Religions',
          'The Creation Story (Christian Perspective)',
          'Creation in Islam',
          'Traditional African Beliefs About Creation',
          'Our Responsibility to Care for Creation',
        ],
      },
      {
        title: 'Moral Teachings',
        topics: [
          'What are Morals and Values?',
          'Honesty and Truthfulness',
          'Respect for Elders and Authority',
          'Hard Work and Diligence',
          'Kindness and Compassion',
        ],
      },
      {
        title: 'Religious Practices',
        topics: [
          'Prayer in Different Religions',
          'Worship and Praise',
          'Fasting and Its Significance',
          'Religious Festivals (Christmas, Easter, Eid)',
          'Traditional Festivals in Ghana',
        ],
      },
      {
        title: 'Family and Relationships',
        topics: [
          'The Family in Religious Teachings',
          'Honouring Parents (Biblical and Quranic Teachings)',
          'Love and Respect in Relationships',
          'Friendship and Peer Relationships',
          'Resolving Conflicts Peacefully',
        ],
      },
    ],
  },
  'JHS 2': {
    chapters: [
      {
        title: 'Sacred Writings',
        topics: [
          'The Bible: Structure and Importance',
          'The Quran: Structure and Importance',
          'Traditional Proverbs and Wisdom',
          'How to Read and Understand Sacred Texts',
          'Key Stories from Sacred Writings',
        ],
      },
      {
        title: 'Religious Leaders and Role Models',
        topics: [
          'Jesus Christ: Life and Teachings',
          'Prophet Muhammad (PBUH): Life and Teachings',
          'Traditional Religious Leaders',
          'Modern Religious Leaders in Ghana',
          'Living a Life of Service',
        ],
      },
      {
        title: 'Adolescence and Moral Choices',
        topics: [
          'Understanding Adolescence',
          'Making Wise Choices',
          'Peer Pressure and How to Handle It',
          'Chastity and Sexual Purity',
          'Avoiding Substance Abuse',
        ],
      },
      {
        title: 'Social Responsibility',
        topics: [
          'Caring for the Needy',
          'Environmental Stewardship',
          'Community Service',
          'Justice and Fairness',
          'Standing Against Evil',
        ],
      },
      {
        title: 'Death and the Afterlife',
        topics: [
          'Christian Beliefs About Death and Resurrection',
          'Islamic Beliefs About Death and Judgment',
          'Traditional Beliefs About Ancestors',
          'Funeral Rites in Different Religions',
          'Living in Light of Eternity',
        ],
      },
    ],
  },
  'JHS 3': {
    chapters: [
      {
        title: 'BECE Prep: Comparative Religion',
        topics: [
          'Similarities Between Religions',
          'Differences Between Religions',
          'Religious Pluralism in Ghana',
          'Interfaith Dialogue',
          'Religion and National Unity',
        ],
      },
      {
        title: 'BECE Prep: Ethics and Moral Philosophy',
        topics: [
          'What is Ethics?',
          'Sources of Moral Authority',
          'Conscience and Moral Decision Making',
          'Ethical Dilemmas and Solutions',
          'Professional Ethics',
        ],
      },
      {
        title: 'BECE Prep: Contemporary Moral Issues',
        topics: [
          'Teenage Pregnancy and Its Effects',
          'Examination Malpractice',
          'Bribery and Corruption',
          'Internet and Social Media Ethics',
          'Environmental Ethics',
        ],
      },
      {
        title: 'BECE Prep: Religion and Society',
        topics: [
          'Religion and Politics',
          'Religion and Education',
          'Religion and Healthcare',
          'Religious Conflicts and Resolution',
          'The Role of Religious Bodies in Development',
        ],
      },
      {
        title: 'BECE Revision and Practice',
        topics: [
          'Review of Key Religious Concepts',
          'Moral Dilemma Analysis',
          'Essay Writing for RME',
          'Objective Questions Practice',
          'Full BECE Mock Examination',
        ],
      },
    ],
  },
};

// XP Configuration
const XP_CONFIG = {
  SECTION_QUESTION: 10,
  SECTION_COMPLETE: 50,
  CHAPTER_QUESTION: 15,
  CHAPTER_COMPLETE: 200,
  YEAR_QUESTION: 20,
  YEAR_COMPLETE: 1000,
  ALL_YEARS_COMPLETE: 5000,
};

// ========================= GENERATION FUNCTIONS =========================

/**
 * Generate section content with images, diagrams, and animations
 */
async function generateSection(subject, year, chapterNumber, chapterTitle, sectionNumber, topic) {
  console.log(`  📝 Generating: ${topic}...`);
  
  const subjectContext = subject === 'Social Studies' 
    ? `Focus on Ghana's history, geography, government, economics, and social issues. Include maps, timelines, and government structure diagrams.`
    : `Cover Christianity, Islam, and Traditional African Religion equally. Include moral stories, religious symbols, and ethical scenarios.`;
  
  const prompt = `Create comprehensive ${subject} content for Ghanaian JHS students.

Year: ${year}
Chapter ${chapterNumber}: ${chapterTitle}
Section ${sectionNumber}: ${topic}
Subject Context: ${subjectContext}

Create engaging educational content (1000-1500 words) in British English with:

## Learning Objectives
[4-5 specific, measurable objectives]

## Introduction
[2-3 engaging paragraphs connecting to Ghanaian student life and experiences]

## Main Content
Create 3-4 detailed subsections with:
- Clear explanations suitable for JHS students (ages 12-15)
- Ghanaian examples, names (Kofi, Ama, Kwame, Adwoa), and places
- Key terms in **bold**
- At least TWO Markdown TABLEs (for comparisons, timelines, key facts)
- TWO ASCII DIAGRAMS or visual representations (maps, flowcharts, concept maps)
- CALLOUT BOXES using > for important notes, tips, and warnings
- Visual separators (---) between subsections
- Bullet points and numbered lists for clarity

${subject === 'Social Studies' ? `
Include diagrams like:
- Map outlines of Ghana showing regions/features
- Government structure charts
- Economic flow diagrams
- Population distribution visuals
- Timeline of historical events
` : `
Include diagrams like:
- Religious symbol comparisons
- Moral decision flowcharts
- Family structure diagrams
- Festival calendars
- Concept maps of religious beliefs
`}

Example Table:
| Concept | Description | Example |
|---------|-------------|---------|
| Democracy | Government by the people | Ghana's elections |

Example ASCII Diagram for ${subject === 'Social Studies' ? 'Government Structure' : 'Moral Decision Making'}:
\`\`\`
${subject === 'Social Studies' ? `
    ┌─────────────────────┐
    │    PRESIDENT        │
    │  (Head of State)    │
    └─────────┬───────────┘
              │
    ┌─────────┴───────────┐
    │                     │
┌───┴───┐           ┌─────┴─────┐
│EXECUTIVE│         │LEGISLATURE │
│Council  │         │(Parliament)│
└─────────┘         └───────────┘
` : `
    ┌─────────────────┐
    │   SITUATION     │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │ Consider Values │
    │ (Religious &    │
    │  Moral Teaching)│
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Make Decision  │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Take Action    │
    └─────────────────┘
`}
\`\`\`

Example Callout:
> 💡 **Key Point**: ${subject === 'Social Studies' ? 'Ghana became independent on 6th March 1957!' : 'All religions teach the Golden Rule: treat others as you want to be treated.'}

> ⚠️ **BECE Tip**: This topic often appears in BECE exams. Pay attention to ${subject === 'Social Studies' ? 'dates and names' : 'religious comparisons'}.

## Image Suggestions
[List 3-4 specific image descriptions that would enhance this section, e.g., "Map of Ghana showing all 16 regions", "Photo of traditional Ghanaian chief"]

## Animation Ideas
[List 1-2 animation concepts, e.g., "Animated timeline of Ghana's independence", "Interactive map showing population density"]

## Worked Examples / Case Studies
[3 detailed examples with step-by-step analysis or real-life scenarios]

## Summary
[6-8 bullet points of key takeaways]

## Key Vocabulary
| Term | Definition | Example in Context |
|------|------------|-------------------|
[Include 12-15 terms specific to this topic]

Now create 5 multiple-choice questions in this JSON format at the end:
{
  "questions": [
    {
      "id": "s${sectionNumber}_q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy|medium|hard",
      "topic": "${topic}",
      "xpValue": ${XP_CONFIG.SECTION_QUESTION}
    }
  ]
}

Make content engaging, culturally relevant, BECE-aligned, and age-appropriate for JHS students.`;

  // Wrap in retry logic for connection resilience
  return await withRetry(async () => {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{
        role: 'user',
        content: prompt
      }],
      temperature: 0.7,
      max_tokens: 4000
    });

    const content = response.choices[0].message.content;
    
    // Extract JSON questions
    const jsonMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    let questions = [];
    
    if (jsonMatch) {
      try {
        questions = JSON.parse(jsonMatch[0]).questions;
      } catch (e) {
        console.log(`    ⚠️ Warning: Could not parse questions JSON for ${topic}`);
      }
    }
    
    // Remove JSON from content
    const markdownContent = content.replace(/\{[\s\S]*"questions"[\s\S]*\}/, '').trim();
    
    // Extract image suggestions and animation ideas
    const imageSuggestions = extractSection(content, 'Image Suggestions');
    const animationIdeas = extractSection(content, 'Animation Ideas');
    
    return {
      content: markdownContent,
      questions: questions,
      imageSuggestions: imageSuggestions,
      animationIdeas: animationIdeas
    };
  }, `Generate ${topic}`);
}

/**
 * Extract a section from markdown content
 */
function extractSection(content, sectionTitle) {
  const regex = new RegExp(`## ${sectionTitle}([\\s\\S]*?)(?=##|$)`, 'i');
  const match = content.match(regex);
  return match ? match[1].trim() : '';
}

/**
 * Generate chapter review questions (20 questions)
 */
async function generateChapterReview(subject, year, chapterNumber, chapterTitle, topics) {
  console.log(`  📋 Generating Chapter ${chapterNumber} Review (20 questions)...`);
  
  const prompt = `Create 20 comprehensive review questions for this ${subject} chapter:

Year: ${year}
Chapter ${chapterNumber}: ${chapterTitle}
Topics covered: ${topics.join(', ')}

Create 20 multiple-choice questions that:
- Test understanding across ALL topics in this chapter
- Include a mix: 6 easy, 8 medium, 6 hard
- Use Ghanaian contexts, names, and examples
- Written in British English
- Align with BECE examination standards
- Include questions that test:
  * Recall of facts
  * Understanding of concepts
  * Application to real-life situations
  * Analysis and comparison

Return ONLY valid JSON in this exact format:
{
  "questions": [
    {
      "id": "ch${chapterNumber}_q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy|medium|hard",
      "topic": "relevant topic from the chapter",
      "xpValue": ${XP_CONFIG.CHAPTER_QUESTION}
    }
  ]
}`;

  // Wrap in retry logic
  return await withRetry(async () => {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{
        role: 'user',
        content: prompt
      }],
      temperature: 0.7,
      max_tokens: 6000
    });

    const content = response.choices[0].message.content;
    const jsonMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    
    if (!jsonMatch) {
      throw new Error('Failed to extract questions JSON');
    }
    
    const parsed = JSON.parse(jsonMatch[0]);
    return parsed.questions;
  }, `Chapter ${chapterNumber} Review`);
}

/**
 * Generate year-end assessment (40 questions)
 */
async function generateYearEndAssessment(subject, year, allChapters) {
  console.log(`\n📝 Generating Year-End Assessment (40 questions)...`);
  
  const chapterSummary = allChapters.map(ch => `${ch.title}: ${ch.topics.join(', ')}`).join('\n');
  
  const prompt = `Create a comprehensive 40-question BECE-style year-end assessment for:

Subject: ${subject}
Year: ${year}

Chapters and Topics covered:
${chapterSummary}

Create 40 multiple-choice questions that:
- Cover ALL chapters and topics from the year comprehensively
- Simulate actual BECE examination conditions
- Include: 12 easy, 16 medium, 12 hard questions
- Use Ghanaian contexts, current events, and real-world applications
- Written in British English with proper grammar
- Test various cognitive levels:
  * Knowledge (facts, definitions)
  * Comprehension (understanding)
  * Application (using knowledge)
  * Analysis (comparing, contrasting)

Include questions about:
${subject === 'Social Studies' ? `
- Ghana's geography and regions
- Historical dates and events
- Government structure and processes
- Economic activities
- Social issues and solutions
- Map interpretation
- Current affairs related to Ghana
` : `
- Religious beliefs and practices (Christianity, Islam, Traditional)
- Moral values and ethical principles
- Religious leaders and their teachings
- Sacred texts and their messages
- Contemporary moral issues
- Religious festivals and observances
- Comparative religion questions
`}

Return ONLY valid JSON:
{
  "questions": [
    {
      "id": "year_q1",
      "questionText": "...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "correctAnswer": "A",
      "explanation": "...",
      "difficulty": "easy|medium|hard",
      "chapter": "relevant chapter",
      "topic": "specific topic",
      "xpValue": ${XP_CONFIG.YEAR_QUESTION}
    }
  ]
}`;

  // Wrap in retry logic
  return await withRetry(async () => {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [{
        role: 'user',
        content: prompt
      }],
      temperature: 0.7,
      max_tokens: 10000
    });

    const content = response.choices[0].message.content;
    const jsonMatch = content.match(/\{[\s\S]*"questions"[\s\S]*\}/);
    
    if (!jsonMatch) {
      throw new Error('Failed to extract questions JSON');
    }
    
    const parsed = JSON.parse(jsonMatch[0]);
    return parsed.questions;
  }, `Year-End Assessment`);
}

/**
 * Generate complete textbook with resume support
 */
async function generateTextbook(subject, year, curriculum, resumeFromChapter = 1, resumeFromSection = 1) {
  const subjectSlug = subject.toLowerCase().replace(/ /g, '_');
  const yearSlug = year.replace(' ', '_').toLowerCase();
  const textbookId = `${subjectSlug}_${yearSlug}`;
  
  console.log(`\n${'='.repeat(70)}`);
  console.log(`📚 GENERATING: ${subject} - ${year} Textbook`);
  console.log(`🤖 Using: OpenAI GPT-4o`);
  console.log(`⏰ Started: ${new Date().toLocaleTimeString()}`);
  if (resumeFromChapter > 1 || resumeFromSection > 1) {
    console.log(`🔄 RESUMING from Chapter ${resumeFromChapter}, Section ${resumeFromSection}`);
  }
  console.log(`${'='.repeat(70)}\n`);

  const yearCurriculum = curriculum[year];
  
  try {
    // Create or update textbook document
    const textbookRef = firestore.collection('textbooks').doc(textbookId);
    
    const totalSections = yearCurriculum.chapters.reduce((sum, ch) => sum + ch.topics.length, 0);
    const totalQuestions = totalSections * 5 + yearCurriculum.chapters.length * 20 + 40;
    
    // Check if textbook exists (for resume)
    const existingDoc = await textbookRef.get();
    if (existingDoc.exists) {
      console.log(`📝 Textbook document exists, updating status...`);
      await textbookRef.update({
        status: 'generating',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await textbookRef.set({
        id: textbookId,
        subject: subject,
        year: year,
        title: `Comprehensive ${subject} - ${year}`,
        description: `Interactive BECE-aligned ${subject} textbook for ${year} students with comprehensive content, images, and assessments`,
        totalChapters: yearCurriculum.chapters.length,
        totalSections: totalSections,
        totalQuestions: totalQuestions,
        status: 'generating',
        generatedBy: 'OpenAI GPT-4o',
        features: ['Interactive Content', 'Images', 'Diagrams', 'Animations', 'BECE Practice'],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    console.log(`✅ Textbook document ready: ${textbookId}\n`);

    // Track all questions for local JSON export
    const allContent = {
      textbookId,
      subject,
      year,
      chapters: []
    };

    // Generate chapters and sections
    for (let chIndex = 0; chIndex < yearCurriculum.chapters.length; chIndex++) {
      const chapter = yearCurriculum.chapters[chIndex];
      const chapterNum = chIndex + 1;
      
      // Skip chapters before resume point
      if (chapterNum < resumeFromChapter) {
        console.log(`\n⏭️ Skipping Chapter ${chapterNum}/${yearCurriculum.chapters.length}: ${chapter.title} (already complete)`);
        continue;
      }
      
      console.log(`\n📖 Chapter ${chapterNum}/${yearCurriculum.chapters.length}: ${chapter.title}`);

      const sections = [];
      const chapterContent = {
        chapterNumber: chapterNum,
        title: chapter.title,
        sections: []
      };

      // Generate sections
      for (let sIndex = 0; sIndex < chapter.topics.length; sIndex++) {
        const topic = chapter.topics[sIndex];
        const sectionNum = sIndex + 1;
        
        // Skip sections before resume point (only for the resume chapter)
        if (chapterNum === resumeFromChapter && sectionNum < resumeFromSection) {
          console.log(`  ⏭️ Skipping: ${topic} (already complete)`);
          continue;
        }
        
        // Check if section already exists in Firestore
        const exists = await sectionExists(textbookId, chapterNum, sectionNum);
        if (exists) {
          console.log(`  ⏭️ Skipping: ${topic} (found in Firestore)`);
          continue;
        }
        
        const sectionData = await generateSection(
          subject,
          year,
          chapterNum,
          chapter.title,
          sectionNum,
          topic
        );

        const sectionId = `section_${chapterNum}_${sectionNum}`;
        
        // Save section to Firestore with retry
        await withRetry(async () => {
          await textbookRef
            .collection('chapters')
            .doc(`chapter_${chapterNum}`)
            .collection('sections')
            .doc(sectionId)
            .set({
              id: sectionId,
              chapterNumber: chapterNum,
              sectionNumber: sectionNum,
              title: topic,
              content: sectionData.content,
              questions: sectionData.questions,
              imageSuggestions: sectionData.imageSuggestions,
              animationIdeas: sectionData.animationIdeas,
              xpReward: XP_CONFIG.SECTION_COMPLETE,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }, `Save section ${topic}`);

        sections.push({ 
          id: sectionId, 
          title: topic, 
          questionCount: sectionData.questions.length 
        });
        
        chapterContent.sections.push({
          sectionNumber: sectionNum,
          title: topic,
          content: sectionData.content,
          questions: sectionData.questions,
          imageSuggestions: sectionData.imageSuggestions,
          animationIdeas: sectionData.animationIdeas
        });
        
        console.log(`    ✅ Saved: ${topic} (${sectionData.questions.length} questions)`);

        // Rate limiting - longer delay for stability
        await sleep(3000);
      }

      // Check if chapter review already exists
      const reviewExists = await chapterReviewExists(textbookId, chapterNum);
      let chapterReviewQuestions;
      
      if (reviewExists) {
        console.log(`  ⏭️ Chapter Review already exists, skipping...`);
        chapterReviewQuestions = [];
      } else {
        // Generate chapter review questions (20 questions)
        chapterReviewQuestions = await generateChapterReview(
          subject,
          year,
          chapterNum,
          chapter.title,
          chapter.topics
        );

        // Save chapter review questions with retry
        await withRetry(async () => {
          await textbookRef
            .collection('chapters')
            .doc(`chapter_${chapterNum}`)
            .collection('questions')
            .doc('chapter_review')
            .set({
              type: 'chapter_review',
              chapterNumber: chapterNum,
              questions: chapterReviewQuestions,
              totalQuestions: chapterReviewQuestions.length,
              xpReward: XP_CONFIG.CHAPTER_COMPLETE,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }, `Save Chapter ${chapterNum} Review`);

        console.log(`    ✅ Chapter Review: ${chapterReviewQuestions.length} questions saved`);
      }
      
      chapterContent.chapterReviewQuestions = chapterReviewQuestions;

      // Save chapter metadata with retry
      await withRetry(async () => {
        await textbookRef
          .collection('chapters')
          .doc(`chapter_${chapterNum}`)
          .set({
            id: `chapter_${chapterNum}`,
            chapterNumber: chapterNum,
            title: chapter.title,
            sections: sections,
            totalSections: sections.length,
            xpReward: XP_CONFIG.CHAPTER_COMPLETE,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }, `Save Chapter ${chapterNum} metadata`);

      allContent.chapters.push(chapterContent);
      console.log(`  ✅ Chapter ${chapterNum} complete!\n`);
      
      // Longer pause between chapters for stability
      await sleep(5000);
    }

    // Check if year-end assessment already exists
    const yearEndExists = await yearEndAssessmentExists(textbookId);
    let yearEndQuestions;
    
    if (yearEndExists) {
      console.log(`\n⏭️ Year-End Assessment already exists, skipping...`);
      yearEndQuestions = [];
    } else {
      // Generate year-end assessment (40 questions)
      yearEndQuestions = await generateYearEndAssessment(subject, year, yearCurriculum.chapters);

      // Save year-end assessment with retry
      await withRetry(async () => {
        await textbookRef
          .collection('assessments')
          .doc('year_end')
          .set({
            type: 'year_end_assessment',
            year: year,
            subject: subject,
            questions: yearEndQuestions,
            totalQuestions: yearEndQuestions.length,
            xpReward: XP_CONFIG.YEAR_COMPLETE,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }, `Save Year-End Assessment`);

      console.log(`  ✅ Year-End Assessment: ${yearEndQuestions.length} questions saved\n`);
    }
    
    allContent.yearEndAssessment = yearEndQuestions;

    // Save local JSON file
    const outputDir = path.join(__dirname, 'assets', `${subjectSlug}_${yearSlug}`);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    const jsonPath = path.join(outputDir, `${textbookId}_complete.json`);
    fs.writeFileSync(jsonPath, JSON.stringify(allContent, null, 2));
    console.log(`  📁 Local JSON saved: ${jsonPath}`);

    // Mark as published
    await textbookRef.update({
      status: 'published',
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`\n${'='.repeat(70)}`);
    console.log(`✅ ${subject} ${year} TEXTBOOK GENERATION COMPLETE!`);
    console.log(`⏰ Finished: ${new Date().toLocaleTimeString()}`);
    console.log(`${'='.repeat(70)}\n`);

    return { success: true, textbookId, subject, year };
  } catch (error) {
    console.error(`\n❌ Error generating ${subject} ${year}:`, error);
    
    // Mark as failed
    await firestore.collection('textbooks').doc(textbookId).update({
      status: 'failed',
      error: error.message,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: false, subject, year, error: error.message };
  }
}

/**
 * Generate index files for a subject
 */
async function generateSubjectIndex(subject, curriculum) {
  const subjectSlug = subject.toLowerCase().replace(/ /g, '_');
  
  const index = {
    subject: subject,
    description: `Comprehensive ${subject} textbooks for JHS 1-3, BECE-aligned`,
    years: Object.keys(curriculum).map(year => ({
      year: year,
      textbookId: `${subjectSlug}_${year.replace(' ', '_').toLowerCase()}`,
      chapters: curriculum[year].chapters.length,
      totalSections: curriculum[year].chapters.reduce((sum, ch) => sum + ch.topics.length, 0)
    })),
    generatedAt: new Date().toISOString(),
    generatedBy: 'OpenAI GPT-4o'
  };
  
  // Save to Firestore
  await firestore.collection('textbook_indexes').doc(subjectSlug).set(index);
  
  // Save local JSON
  const indexPath = path.join(__dirname, 'assets', `${subjectSlug}_index.json`);
  fs.writeFileSync(indexPath, JSON.stringify(index, null, 2));
  
  console.log(`📑 Index created for ${subject}`);
  return index;
}

// ========================= MAIN EXECUTION =========================

async function main() {
  console.log('\n' + '📚'.repeat(35));
  console.log('📖 SOCIAL STUDIES & RME TEXTBOOK GENERATION');
  console.log('📚'.repeat(35));
  console.log(`\n⏰ Started: ${new Date().toLocaleString()}`);
  console.log(`🤖 Model: OpenAI GPT-4o`);
  console.log(`📍 Subjects: Social Studies, RME`);
  console.log(`📍 Years: JHS 1, JHS 2, JHS 3`);
  console.log(`⏱️  Estimated time: 45-60 minutes total`);
  console.log(`🔄 Retry: ${RETRY_CONFIG.maxRetries} attempts with exponential backoff\n`);

  // Check for resume mode
  if (RESUME_CONFIG.enabled) {
    console.log('🔄 RESUME MODE ENABLED');
    console.log(`   Subject: ${RESUME_CONFIG.subject || 'all'}`);
    console.log(`   Year: ${RESUME_CONFIG.year || 'all'}`);
    console.log(`   Chapter: ${RESUME_CONFIG.chapter || '1'}`);
    console.log(`   Section: ${RESUME_CONFIG.section || '1'}`);
    console.log('');
  }

  const results = [];

  // Determine what to generate
  const args = process.argv.slice(2).filter(a => !a.startsWith('--'));
  const generateSocial = !RESUME_CONFIG.enabled || 
    (RESUME_CONFIG.subject === 'social studies') || 
    (args.length === 0 || args.includes('social'));
  const generateRME = !RESUME_CONFIG.enabled || 
    (RESUME_CONFIG.subject === 'religious and moral education' || RESUME_CONFIG.subject === 'rme') ||
    (args.length === 0 || args.includes('rme'));
  
  const yearsToGenerate = args.filter(a => a.startsWith('jhs')).map(a => `JHS ${a.charAt(3)}`);
  let years = yearsToGenerate.length > 0 ? yearsToGenerate : ['JHS 1', 'JHS 2', 'JHS 3'];
  
  // Filter years for resume mode
  if (RESUME_CONFIG.enabled && RESUME_CONFIG.year) {
    const resumeYearIndex = years.indexOf(RESUME_CONFIG.year);
    if (resumeYearIndex >= 0) {
      years = years.slice(resumeYearIndex);
    }
  }

  console.log(`📝 Will generate:`);
  if (generateSocial) console.log(`   - Social Studies: ${years.join(', ')}`);
  if (generateRME) console.log(`   - RME: ${years.join(', ')}`);
  console.log('');

  // Generate Social Studies
  if (generateSocial && (!RESUME_CONFIG.enabled || RESUME_CONFIG.subject === 'social studies' || !RESUME_CONFIG.subject)) {
    console.log('\n' + '🌍'.repeat(35));
    console.log('📖 GENERATING SOCIAL STUDIES TEXTBOOKS');
    console.log('🌍'.repeat(35) + '\n');
    
    for (let i = 0; i < years.length; i++) {
      const year = years[i];
      if (SOCIAL_STUDIES_CURRICULUM[year]) {
        // Determine resume chapter/section
        const isFirstResumeYear = RESUME_CONFIG.enabled && 
          RESUME_CONFIG.subject === 'social studies' && 
          year === RESUME_CONFIG.year;
        const resumeChapter = isFirstResumeYear ? (RESUME_CONFIG.chapter || 1) : 1;
        const resumeSection = isFirstResumeYear ? (RESUME_CONFIG.section || 1) : 1;
        
        try {
          const result = await generateTextbook('Social Studies', year, SOCIAL_STUDIES_CURRICULUM, resumeChapter, resumeSection);
          results.push(result);
        } catch (error) {
          console.error(`\n❌ Error generating Social Studies ${year}: ${error.message}`);
          results.push({ subject: 'Social Studies', year, success: false, error: error.message });
        }

        if (i < years.length - 1) {
          console.log(`\n⏸️  Waiting 10 seconds before next year...\n`);
          await sleep(10000);
        }
      }
    }
    
    await generateSubjectIndex('Social Studies', SOCIAL_STUDIES_CURRICULUM);
  }

  // Generate RME
  const shouldGenerateRME = generateRME && 
    (!RESUME_CONFIG.enabled || 
     RESUME_CONFIG.subject === 'religious and moral education' || 
     RESUME_CONFIG.subject === 'rme' || 
     (RESUME_CONFIG.subject === 'social studies' && results.some(r => r.success)));
  
  if (shouldGenerateRME) {
    console.log('\n' + '🙏'.repeat(35));
    console.log('📖 GENERATING RME TEXTBOOKS');
    console.log('🙏'.repeat(35) + '\n');
    
    // Reset years for RME if coming from Social Studies resume
    const rmeYears = (RESUME_CONFIG.enabled && RESUME_CONFIG.subject === 'rme' && RESUME_CONFIG.year) 
      ? ['JHS 1', 'JHS 2', 'JHS 3'].slice(['JHS 1', 'JHS 2', 'JHS 3'].indexOf(RESUME_CONFIG.year))
      : ['JHS 1', 'JHS 2', 'JHS 3'];
    
    for (let i = 0; i < rmeYears.length; i++) {
      const year = rmeYears[i];
      if (RME_CURRICULUM[year]) {
        const isFirstResumeYear = RESUME_CONFIG.enabled && 
          (RESUME_CONFIG.subject === 'rme' || RESUME_CONFIG.subject === 'religious and moral education') && 
          year === RESUME_CONFIG.year;
        const resumeChapter = isFirstResumeYear ? (RESUME_CONFIG.chapter || 1) : 1;
        const resumeSection = isFirstResumeYear ? (RESUME_CONFIG.section || 1) : 1;
        
        try {
          const result = await generateTextbook('Religious and Moral Education', year, RME_CURRICULUM, resumeChapter, resumeSection);
          results.push(result);
        } catch (error) {
          console.error(`\n❌ Error generating RME ${year}: ${error.message}`);
          results.push({ subject: 'Religious and Moral Education', year, success: false, error: error.message });
        }

        if (i < rmeYears.length - 1) {
          console.log(`\n⏸️  Waiting 10 seconds before next year...\n`);
          await sleep(10000);
        }
      }
    }
    
    await generateSubjectIndex('Religious and Moral Education', RME_CURRICULUM);
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('📊 GENERATION SUMMARY');
  console.log('='.repeat(70) + '\n');

  results.forEach(({ subject, year, success, error }) => {
    if (success) {
      console.log(`✅ ${subject} ${year}: SUCCESS`);
    } else {
      console.log(`❌ ${subject} ${year}: FAILED - ${error}`);
    }
  });

  const successCount = results.filter(r => r.success).length;
  const totalExpected = (generateSocial ? years.length : 0) + (generateRME ? years.length : 0);
  
  console.log(`\n🎯 Total: ${successCount}/${results.length} textbooks generated`);
  console.log(`⏰ Completed: ${new Date().toLocaleString()}`);
  console.log(`\n💰 Estimated cost: $${(successCount * 0.50).toFixed(2)} (OpenAI)\n`);

  process.exit(successCount === results.length ? 0 : 1);
}

// Run the main function
main().catch(error => {
  console.error('\n💥 FATAL ERROR:', error);
  console.error('\n🔄 To resume, run:');
  console.error('   node generate_social_rme_textbooks.js --resume social_studies --year "JHS 1" --chapter 1 --section 3');
  process.exit(1);
});
