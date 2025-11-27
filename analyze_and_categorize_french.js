const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// French Topics (12 topics based on curriculum strands)
const FRENCH_TOPICS = {
  // Strand 1: Communication
  'Greetings': [
    'greetings', 'hello', 'bonjour', 'salut', 'au revoir', 'goodbye', 'comment allez-vous',
    'how are you', 'enchanté', 'nice to meet you', 'introductions', 'polite expressions'
  ],

  'Personal Information': [
    'personal information', 'name', 'age', 'address', 'telephone', 'family', 'profession',
    'nationality', 'hobbies', 'interests', 'personal details', 'identity', 'personal data'
  ],

  'Everyday Conversations': [
    'everyday conversations', 'daily conversations', 'casual talk', 'small talk', 'chat',
    'conversation', 'dialogue', 'speaking practice', 'oral communication', 'daily life',
    'routine conversations', 'informal speech'
  ],

  // Strand 2: Grammar
  'Verbs & Conjugation': [
    'verbs', 'conjugation', 'verb forms', 'tense', 'present tense', 'past tense', 'future tense',
    'irregular verbs', 'regular verbs', 'auxiliary verbs', 'avoir', 'être', 'faire', 'aller',
    'aller', 'venir', 'partir', 'prendre', 'mettre', 'dire', 'voir', 'savoir', 'pouvoir',
    'vouloir', 'faire', 'falloir', 'devoir', 'mettre', 'prendre', 'venir', 'aller'
  ],

  'Nouns, Gender & Articles': [
    'nouns', 'gender', 'masculine', 'feminine', 'articles', 'definite articles', 'indefinite articles',
    'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de la', 'de l\'', 'des', 'noun agreement', 'gender rules',
    'masculine nouns', 'feminine nouns', 'article agreement', 'definite article', 'indefinite article'
  ],

  'Structure of Sentences': [
    'sentence structure', 'sentence formation', 'syntax', 'word order', 'subject-verb-object',
    'sentence patterns', 'phrase structure', 'grammatical structure', 'sentence building',
    'prepositions', 'prépositions', 'au', 'aux', 'à', 'en', 'dans', 'sur', 'sous', 'avec', 'sans',
    'chez', 'pour', 'par', 'question formation', 'interrogative', 'que', 'qui', 'quoi', 'où',
    'quand', 'comment', 'pourquoi', 'quel', 'quelle', 'quels', 'quelles', 'est-ce que',
    'inversion', 'question words', 'interrogation', 'sentence structure', 'word order'
  ],

  // Strand 3: Reading
  'Comprehension': [
    'comprehension', 'reading comprehension', 'text comprehension', 'understanding',
    'reading skills', 'passage comprehension', 'text analysis', 'reading comprehension questions'
  ],

  'Vocabulary Themes': [
    'vocabulary themes', 'thematic vocabulary', 'topic vocabulary', 'lexical themes',
    'vocabulary categories', 'word themes', 'thematic words', 'vocabulary groups'
  ],

  'Short Text Interpretation': [
    'short text interpretation', 'text interpretation', 'short passages', 'brief texts',
    'text analysis', 'passage interpretation', 'short reading', 'text comprehension'
  ],

  // Strand 4: Writing
  'Guided Writing': [
    'guided writing', 'directed writing', 'writing guidance', 'structured writing',
    'writing prompts', 'writing exercises', 'writing instruction', 'guided composition'
  ],

  'Messages & Emails': [
    'messages', 'emails', 'email writing', 'message writing', 'correspondence',
    'formal messages', 'informal messages', 'electronic communication', 'letter writing'
  ],

  'Short Paragraphs': [
    'short paragraphs', 'paragraph writing', 'brief paragraphs', 'paragraph composition',
    'short compositions', 'paragraph structure', 'concise writing', 'brief writing'
  ]
};

// More intelligent categorization function
function categorizeQuestion(question) {
  const content = `${question.questionText} ${question.options.join(' ')}`.toLowerCase();

  // First, check if the question has explicit topic metadata
  if (question.topics && question.topics.length > 0) {
    const topicMetadata = question.topics[0].toLowerCase();

    // Map metadata topics to our curriculum topics
    if (topicMetadata.includes('greetings') || topicMetadata.includes('communication')) {
      if (content.includes('hello') || content.includes('bonjour') || content.includes('salut')) {
        return 'Greetings';
      }
      if (content.includes('personal') || content.includes('information') || content.includes('name')) {
        return 'Personal Information';
      }
      return 'Everyday Conversations';
    }
    if (topicMetadata.includes('grammar') || topicMetadata.includes('verbs')) {
      if (content.includes('verb') || content.includes('conjugation') || content.includes('tense')) {
        return 'Verbs & Conjugation';
      }
      if (content.includes('noun') || content.includes('gender') || content.includes('article')) {
        return 'Nouns, Gender & Articles';
      }
      return 'Structure of Sentences';
    }
    if (topicMetadata.includes('reading') || topicMetadata.includes('comprehension')) {
      if (content.includes('vocabulary') || content.includes('themes')) {
        return 'Vocabulary Themes';
      }
      if (content.includes('short text') || content.includes('interpretation')) {
        return 'Short Text Interpretation';
      }
      return 'Comprehension';
    }
    if (topicMetadata.includes('writing') || topicMetadata.includes('composition')) {
      if (content.includes('message') || content.includes('email')) {
        return 'Messages & Emails';
      }
      if (content.includes('paragraph') || content.includes('short')) {
        return 'Short Paragraphs';
      }
      return 'Guided Writing';
    }
  }

  // Check partHeader for additional categorization clues
  if (question.partHeader) {
    const partHeader = question.partHeader.toLowerCase();
    if (partHeader.includes('greetings') || partHeader.includes('communication')) {
      return 'Greetings';
    }
    if (partHeader.includes('grammar') || partHeader.includes('verbs')) {
      return 'Verbs & Conjugation';
    }
    if (partHeader.includes('reading') || partHeader.includes('comprehension')) {
      return 'Comprehension';
    }
    if (partHeader.includes('writing') || partHeader.includes('composition')) {
      return 'Guided Writing';
    }
  }

  // Check paperInstructions for clues
  if (question.paperInstructions) {
    const instructions = question.paperInstructions.toLowerCase();
    if (instructions.includes('greetings') || instructions.includes('communication')) {
      return 'Greetings';
    }
    if (instructions.includes('grammar') || instructions.includes('verbs')) {
      return 'Verbs & Conjugation';
    }
    if (instructions.includes('reading') || instructions.includes('comprehension')) {
      return 'Comprehension';
    }
    if (instructions.includes('writing') || instructions.includes('composition')) {
      return 'Guided Writing';
    }
  }

  // Check for common French question patterns
  if (content.includes('faim') || content.includes('froid') || content.includes('soif')) {
    return 'Vocabulary Themes'; // Weather, feelings, basic vocabulary
  }
  if (content.includes('fruit') || content.includes('oiseau') || content.includes('poisson')) {
    return 'Vocabulary Themes'; // Animals, food, objects
  }
  if (content.includes('quelle') || content.includes('comment') || content.includes('où')) {
    return 'Everyday Conversations'; // Question words for conversations
  }
  if (content.includes('lettre') || content.includes('message') || content.includes('email')) {
    return 'Messages & Emails';
  }
  if (content.includes('phrase') || content.includes('paragraphe')) {
    return 'Short Paragraphs';
  }

  // Specific grammar pattern matching
  if (content.includes('au') || content.includes('aux') || content.includes('à') ||
      content.includes('en') || content.includes('dans') || content.includes('sur') ||
      content.includes('sous') || content.includes('avec') || content.includes('sans') ||
      content.includes('chez') || content.includes('pour') || content.includes('par')) {
    // Check if it's a preposition choice question (contains multiple prepositions)
    if ((content.match(/\bau\b/g) || []).length > 0 && (content.match(/\bà\b/g) || []).length > 0) {
      return 'Structure of Sentences'; // Preposition questions
    }
    if ((content.match(/\ben\b/g) || []).length > 0 && (content.match(/\bau\b/g) || []).length > 0) {
      return 'Structure of Sentences'; // Preposition questions
    }
    if ((content.match(/\ben\b/g) || []).length > 0 && (content.match(/\bà\b/g) || []).length > 0 && (content.match(/\bdans\b/g) || []).length > 0) {
      return 'Structure of Sentences'; // Preposition questions
    }
  }

  // Question formation patterns
  if (content.includes('que fais') || content.includes('où habites') ||
      content.includes('comment allez') || content.includes('quel âge') ||
      content.includes('quelle heure') || content.includes('qu\'est-ce que')) {
    return 'Structure of Sentences'; // Question formation
  }

  // Article patterns
  if (content.includes('du ') || content.includes('de la ') || content.includes('de l\'')) {
    return 'Nouns, Gender & Articles'; // Partitive articles
  }

  // Fallback to keyword matching with scoring
  const scores = {};

  for (const [topic, keywords] of Object.entries(FRENCH_TOPICS)) {
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

async function analyzeAndCategorizeFrench() {
  try {
    console.log('🇫🇷 Fetching all French questions from Firestore...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'french')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      questions.push({ id: doc.id, ...doc.data() });
    });

    console.log(`✅ Found ${questions.length} French questions\n`);

    console.log('🤖 Analyzing question content with intelligent categorization...\n');

    const categorized = {};
    const unclassified = [];
    const classificationLog = [];

    // Initialize categories
    Object.keys(FRENCH_TOPICS).forEach(topic => {
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
    const baseDir = path.join('assets', 'french_questions_by_topic');
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
    console.log('📊 FRENCH CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total French Questions: ${questions.length}`);
    console.log(`Categorized Questions: ${questions.length - unclassified.length} (${classificationData.classificationRate}%)`);
    console.log(`Unclassified Questions: ${unclassified.length}`);
    console.log('='.repeat(70));

    console.log('\n📄 Files saved to: assets\\french_questions_by_topic');
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
analyzeAndCategorizeFrench();