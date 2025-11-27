const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// English Language Topics (15 topics based on curriculum strands)
const ENGLISH_TOPICS = {
  // Strand 1: Oral Language
  'Listening Skills': [
    'listening skills', 'listening', 'listen', 'hear', 'auditory', 'audio',
    'comprehension listening', 'listening comprehension', 'oral comprehension',
    'listening exercises', 'listening activities', 'listening test'
  ],

  'Speaking Skills': [
    'speaking skills', 'speaking', 'speak', 'talk', 'oral communication',
    'verbal communication', 'oral presentation', 'presentation skills',
    'public speaking', 'conversation', 'dialogue', 'discuss', 'express'
  ],

  'Pronunciation': [
    'pronunciation', 'pronounce', 'phonetics', 'phonetic', 'accent', 'intonation',
    'stress', 'rhythm', 'articulation', 'enunciation', 'vowel sounds', 'consonant sounds',
    'sound production', 'speech sounds', 'phonological'
  ],

  // Strand 2: Reading
  'Comprehension': [
    'comprehension', 'understand', 'reading comprehension', 'text comprehension',
    'passage comprehension', 'reading skills', 'comprehend', 'interpret',
    'reading comprehension questions', 'inference', 'main idea', 'details'
  ],

  'Vocabulary Development': [
    'vocabulary', 'vocabulary development', 'word knowledge', 'lexical',
    'word meaning', 'vocabulary building', 'word choice', 'diction',
    'word usage', 'semantic', 'lexicon', 'terminology', 'glossary'
  ],

  'Literary Appreciation': [
    'literary appreciation', 'literary analysis', 'literary devices', 'literary terms',
    'literary elements', 'appreciate literature', 'literary criticism', 'literary understanding',
    'figurative language', 'metaphor', 'simile', 'personification', 'imagery'
  ],

  // Strand 3: Grammar
  'Parts of Speech': [
    'parts of speech', 'noun', 'verb', 'adjective', 'adverb', 'pronoun',
    'preposition', 'conjunction', 'interjection', 'article', 'determiner',
    'grammatical categories', 'word classes', 'lexical categories'
  ],

  'Sentence Structure': [
    'sentence structure', 'sentence types', 'simple sentence', 'compound sentence',
    'complex sentence', 'sentence construction', 'syntax', 'sentence formation',
    'sentence patterns', 'clause', 'phrase', 'subject', 'predicate'
  ],

  'Punctuation & Usage': [
    'punctuation', 'punctuation marks', 'comma', 'period', 'question mark',
    'exclamation mark', 'colon', 'semicolon', 'quotation marks', 'apostrophe',
    'hyphen', 'dash', 'parentheses', 'brackets', 'usage', 'grammar usage'
  ],

  // Strand 4: Writing
  'Guided Writing': [
    'guided writing', 'writing guidance', 'directed writing', 'writing prompts',
    'writing exercises', 'structured writing', 'writing instruction', 'writing tasks',
    'guided composition', 'writing activities', 'writing practice'
  ],

  'Composition': [
    'composition', 'essay writing', 'creative writing', 'writing composition',
    'narrative writing', 'descriptive writing', 'expository writing', 'persuasive writing',
    'formal writing', 'informal writing', 'letter writing', 'report writing'
  ],

  'Summary Writing': [
    'summary writing', 'summarize', 'summary', 'summarization', 'condense',
    'paraphrase', 'abstract', 'synopsis', 'outline', 'key points', 'main points',
    'summary skills', 'summarizing text', 'summary techniques'
  ],

  // Strand 5: Literature
  'Prose': [
    'prose', 'prose fiction', 'novel', 'short story', 'narrative prose',
    'prose writing', 'prose literature', 'fiction', 'storytelling', 'narrative',
    'plot', 'character', 'setting', 'theme', 'prose analysis'
  ],

  'Poetry': [
    'poetry', 'poem', 'poetic', 'verse', 'poetic devices', 'poetic forms',
    'rhyme', 'rhythm', 'meter', 'stanza', 'poetic language', 'poetic analysis',
    'poetic appreciation', 'poems', 'poetic terms', 'lyric', 'sonnet'
  ],

  'Drama': [
    'drama', 'play', 'theatre', 'dramatic', 'dramatic literature', 'script',
    'stage', 'performance', 'dramatic analysis', 'dramatic elements', 'scene',
    'act', 'dialogue', 'monologue', 'character development', 'dramatic techniques'
  ]
};

// More intelligent categorization function
function categorizeQuestion(question) {
  const content = `${question.questionText} ${question.options.join(' ')}`.toLowerCase();

  // First, check if the question has explicit topic metadata
  if (question.topics && question.topics.length > 0) {
    const topicMetadata = question.topics[0].toLowerCase();

    // Map metadata topics to our curriculum topics
    if (topicMetadata.includes('comprehension') || topicMetadata.includes('reading')) {
      return 'Comprehension';
    }
    if (topicMetadata.includes('grammar') || topicMetadata.includes('parts of speech')) {
      return 'Parts of Speech';
    }
    if (topicMetadata.includes('vocabulary') || topicMetadata.includes('word')) {
      return 'Vocabulary Development';
    }
    if (topicMetadata.includes('literature') || topicMetadata.includes('poetry') || topicMetadata.includes('drama')) {
      if (content.includes('poem') || content.includes('verse') || content.includes('rhyme')) {
        return 'Poetry';
      }
      if (content.includes('play') || content.includes('scene') || content.includes('act')) {
        return 'Drama';
      }
      if (content.includes('story') || content.includes('novel') || content.includes('prose')) {
        return 'Prose';
      }
      return 'Literary Appreciation';
    }
    if (topicMetadata.includes('writing') || topicMetadata.includes('composition')) {
      if (content.includes('summary') || content.includes('summarize')) {
        return 'Summary Writing';
      }
      if (content.includes('letter') || content.includes('essay') || content.includes('composition')) {
        return 'Composition';
      }
      return 'Guided Writing';
    }
  }

  // Check partHeader for additional categorization clues
  if (question.partHeader) {
    const partHeader = question.partHeader.toLowerCase();
    if (partHeader.includes('composition')) {
      return 'Composition';
    }
    if (partHeader.includes('summary')) {
      return 'Summary Writing';
    }
    if (partHeader.includes('letter') || partHeader.includes('writing')) {
      return 'Guided Writing';
    }
  }

  // Check paperInstructions for clues
  if (question.paperInstructions) {
    const instructions = question.paperInstructions.toLowerCase();
    if (instructions.includes('composition') || instructions.includes('write')) {
      return 'Composition';
    }
    if (instructions.includes('summary')) {
      return 'Summary Writing';
    }
  }
  const scores = {};

  for (const [topic, keywords] of Object.entries(ENGLISH_TOPICS)) {
    scores[topic] = 0;

    for (const keyword of keywords) {
      const regex = new RegExp(keyword.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      const matches = content.match(regex);
      if (matches) {
        scores[topic] += matches.length;
      }
    }
  }

  // Find the topic with the highest score
  let bestTopic = null;
  let bestScore = 0;

  for (const [topic, score] of Object.entries(scores)) {
    if (score > bestScore) {
      bestScore = score;
      bestTopic = topic;
    }
  }

  // Only categorize if we have at least 2 keyword matches to avoid false positives
  return bestScore >= 2 ? bestTopic : null;
}

async function analyzeAndCategorizeEnglish() {
  try {
    console.log('📚 Fetching all English Language questions from Firestore...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'english')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      questions.push({ id: doc.id, ...doc.data() });
    });

    console.log(`✅ Found ${questions.length} English Language questions\n`);

    console.log('🤖 Analyzing question content with intelligent categorization...\n');

    const categorized = {};
    const unclassified = [];
    const classificationLog = [];

    // Initialize categories
    Object.keys(ENGLISH_TOPICS).forEach(topic => {
      categorized[topic] = [];
    });

    let processed = 0;
    for (const question of questions) {
      const topic = categorizeQuestion(question);

      if (topic) {
        categorized[topic].push(question);
        classificationLog.push({
          questionId: question.id,
          topic: topic,
          reason: 'Intelligent keyword matching with scoring'
        });
      } else {
        unclassified.push(question);
        classificationLog.push({
          questionId: question.id,
          topic: 'unclassified',
          reason: 'Insufficient keyword matches'
        });
      }

      processed++;
      if (processed % 100 === 0) {
        console.log(`  Processed ${processed}/${questions.length} questions...`);
      }
    }

    console.log('\n✅ Analysis complete!\n');

    // Create directory for categorized questions
    const baseDir = path.join('assets', 'english_questions_by_topic');
    await fs.mkdir(baseDir, { recursive: true });

    // Save categorized questions
    const indexData = { topics: [] };

    for (const [topic, topicQuestions] of Object.entries(categorized)) {
      const filename = `${topic.toLowerCase().replace(/[^a-z0-9]/g, '_')}.json`;

      const topicData = {
        topic: topic,
        questions: topicQuestions,
        questionCount: topicQuestions.length
      };

      await fs.writeFile(
        path.join(baseDir, filename),
        JSON.stringify(topicData, null, 2)
      );

      indexData.topics.push({
        name: topic,
        filename: filename,
        questionCount: topicQuestions.length
      });

      console.log(`✅ ${topic}: ${topicQuestions.length} questions`);
    }

    // Save index
    await fs.writeFile(
      path.join(baseDir, 'index.json'),
      JSON.stringify(indexData, null, 2)
    );

    // Save unclassified questions
    const unclassifiedData = {
      topic: 'unclassified',
      questions: unclassified,
      questionCount: unclassified.length
    };

    await fs.writeFile(
      path.join(baseDir, '_unclassified.json'),
      JSON.stringify(unclassifiedData, null, 2)
    );

    // Save classification log
    const classificationData = {
      totalQuestions: questions.length,
      categorizedQuestions: questions.length - unclassified.length,
      unclassifiedQuestions: unclassified.length,
      classificationRate: ((questions.length - unclassified.length) / questions.length * 100).toFixed(1),
      classifications: classificationLog
    };

    await fs.writeFile(
      path.join(baseDir, '_classification_details.json'),
      JSON.stringify(classificationData, null, 2)
    );

    console.log(`\n❌ Unclassified: ${unclassified.length} questions`);

    console.log('\n' + '='.repeat(70));
    console.log('📊 ENGLISH LANGUAGE CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total English Language Questions: ${questions.length}`);
    console.log(`Categorized Questions: ${questions.length - unclassified.length} (${classificationData.classificationRate}%)`);
    console.log(`Unclassified Questions: ${unclassified.length}`);
    console.log('='.repeat(70));

    console.log('\n📄 Files saved to: assets\\english_questions_by_topic');
    console.log('\n📋 Topics created:');
    indexData.topics.forEach(topic => {
      console.log(`   - ${topic.name}: ${topic.questionCount} questions`);
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the analysis
analyzeAndCategorizeEnglish();