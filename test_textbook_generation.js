/**
 * Example script to test textbook generation
 * Run with: node test_textbook_generation.js
 * 
 * Make sure to:
 * 1. Have Firebase Admin SDK initialized
 * 2. Set ANTHROPIC_API_KEY environment variable
 */

const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const functions = admin.functions();

// Example 1: Generate a single lesson
async function generateSingleLesson() {
  console.log('🚀 Generating Mathematics lesson on Quadratic Equations...\n');
  
  try {
    const generateContent = functions.httpsCallable('generateTextbookContent');
    
    const result = await generateContent({
      subject: 'Mathematics',
      topic: 'Solving Quadratic Equations by Factorization',
      syllabusReference: 'NACCA 2024 Mathematics B3.2',
      grade: 'BECE',
      contentType: 'full_lesson',
      language: 'en',
    });

    console.log('✅ Success!');
    console.log('Content ID:', result.data.id);
    console.log('Word Count:', result.data.metadata.wordCount);
    console.log('Reading Time:', result.data.metadata.estimatedReadingTime, 'minutes');
    console.log('Tokens Used:', result.data.metadata.tokensUsed);
    console.log('\n--- Content Preview (first 500 chars) ---');
    console.log(result.data.content.substring(0, 500) + '...\n');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Example 2: Generate a chapter with multiple topics
async function generateChapter() {
  console.log('🚀 Generating Science chapter on Human Biology...\n');
  
  try {
    const generateChapter = functions.httpsCallable('generateChapter');
    
    const result = await generateChapter({
      subject: 'Science',
      chapterTitle: 'Human Body Systems',
      grade: 'JHS 3',
      topics: [
        { title: 'The Digestive System', syllabusRef: 'NACCA 2024 Science B3.1' },
        { title: 'The Respiratory System', syllabusRef: 'NACCA 2024 Science B3.2' },
        { title: 'The Circulatory System', syllabusRef: 'NACCA 2024 Science B3.3' },
      ],
    });

    console.log('✅ Chapter generated successfully!');
    console.log('Chapter ID:', result.data.chapterId);
    console.log('Total Sections:', result.data.totalSections);
    console.log('\nSections:');
    result.data.sections.forEach((section, index) => {
      console.log(`  ${index + 1}. ${section.topicTitle} (${section.wordCount} words)`);
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Example 3: Bulk generation with progress monitoring
async function bulkGenerate() {
  console.log('🚀 Starting bulk generation for English topics...\n');
  
  try {
    const bulkGenerate = functions.httpsCallable('bulkGenerateContent');
    
    const result = await bulkGenerate({
      subject: 'English',
      grade: 'BECE',
      batchSize: 3,
      topics: [
        { title: 'Parts of Speech - Nouns', syllabusRef: 'NACCA 2024 English A1.1' },
        { title: 'Parts of Speech - Verbs', syllabusRef: 'NACCA 2024 English A1.2' },
        { title: 'Parts of Speech - Adjectives', syllabusRef: 'NACCA 2024 English A1.3' },
        { title: 'Sentence Structure - Simple Sentences', syllabusRef: 'NACCA 2024 English A2.1' },
        { title: 'Sentence Structure - Compound Sentences', syllabusRef: 'NACCA 2024 English A2.2' },
      ],
    });

    console.log('✅ Bulk generation completed!');
    console.log('Job ID:', result.data.jobId);
    console.log('Total Topics:', result.data.totalTopics);
    console.log('Successful:', result.data.successfulTopics);
    console.log('Failed:', result.data.failedTopics);
    
    console.log('\nResults:');
    result.data.results.forEach((topic) => {
      const status = topic.status === 'success' ? '✅' : '❌';
      console.log(`  ${status} ${topic.topicTitle}`);
      if (topic.status === 'success') {
        console.log(`     Content ID: ${topic.contentId}`);
      } else {
        console.log(`     Error: ${topic.error}`);
      }
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Example 4: Generate practice questions only
async function generatePracticeQuestions() {
  console.log('🚀 Generating practice questions for Science...\n');
  
  try {
    const generateContent = functions.httpsCallable('generateTextbookContent');
    
    const result = await generateContent({
      subject: 'Science',
      topic: 'Photosynthesis',
      syllabusReference: 'NACCA 2024 Science B2.1',
      grade: 'JHS 2',
      contentType: 'practice_questions',
      language: 'en',
    });

    console.log('✅ Practice questions generated!');
    console.log('Content ID:', result.data.id);
    console.log('Word Count:', result.data.metadata.wordCount);
    console.log('\n--- Questions Preview ---');
    console.log(result.data.content.substring(0, 800) + '...\n');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Example 5: Generate content in Twi
async function generateTwiContent() {
  console.log('🚀 Generating content in Twi language...\n');
  
  try {
    const generateContent = functions.httpsCallable('generateTextbookContent');
    
    const result = await generateContent({
      subject: 'RME',
      topic: 'Akan Traditional Values and Beliefs',
      syllabusReference: 'NACCA 2024 RME C1.1',
      grade: 'JHS 1',
      contentType: 'summary',
      language: 'tw', // Twi
    });

    console.log('✅ Twi content generated!');
    console.log('Content ID:', result.data.id);
    console.log('\n--- Content Preview ---');
    console.log(result.data.content.substring(0, 500) + '...\n');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Main menu
async function main() {
  console.log('====================================');
  console.log('  TEXTBOOK GENERATION TEST SUITE   ');
  console.log('====================================\n');

  const examples = [
    { name: 'Single Lesson (Mathematics)', fn: generateSingleLesson },
    { name: 'Chapter Generation (Science)', fn: generateChapter },
    { name: 'Bulk Generation (English)', fn: bulkGenerate },
    { name: 'Practice Questions (Science)', fn: generatePracticeQuestions },
    { name: 'Twi Language Content (RME)', fn: generateTwiContent },
  ];

  // Get example to run from command line argument
  const exampleIndex = parseInt(process.argv[2]) - 1;

  if (exampleIndex >= 0 && exampleIndex < examples.length) {
    const example = examples[exampleIndex];
    console.log(`Running: ${example.name}\n`);
    await example.fn();
  } else {
    console.log('Available examples:');
    examples.forEach((example, index) => {
      console.log(`  ${index + 1}. ${example.name}`);
    });
    console.log('\nUsage: node test_textbook_generation.js <example_number>');
    console.log('Example: node test_textbook_generation.js 1\n');
  }

  console.log('\n====================================');
  console.log('Test completed!');
  console.log('====================================');
  process.exit(0);
}

// Run the script
main().catch(console.error);
