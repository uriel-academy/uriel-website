const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Ga Topics (based on Ghanaian Language curriculum strands)
const GA_TOPICS = {
  // Strand 1: Communication & Oral Skills
  'Greetings & Introductions': [
    'greetings', 'hello', 'introduction', 'polite expressions', 'good morning', 'good afternoon',
    'good evening', 'how are you', 'my name is', 'nice to meet you', 'welcome', 'thank you'
  ],

  'Family & Relationships': [
    'family', 'mother', 'father', 'brother', 'sister', 'grandmother', 'grandfather',
    'aunt', 'uncle', 'cousin', 'relationships', 'family members', 'relatives'
  ],

  'Daily Activities': [
    'daily activities', 'routine', 'wake up', 'eat', 'drink', 'sleep', 'work', 'school',
    'play', 'exercise', 'shopping', 'cooking', 'cleaning', 'housework'
  ],

  // Strand 2: Grammar & Language Structure
  'Nouns & Pronouns': [
    'nouns', 'pronouns', 'names', 'objects', 'people', 'places', 'things',
    'he', 'she', 'it', 'they', 'we', 'you', 'i', 'me', 'him', 'her',
    'person', 'man', 'woman', 'child', 'boy', 'girl', 'name', 'proper noun'
  ],

  'Verbs & Tenses': [
    'verbs', 'action words', 'present', 'past', 'future', 'doing', 'going', 'coming',
    'eating', 'drinking', 'sleeping', 'walking', 'running', 'speaking'
  ],

  'Sentence Structure': [
    'sentence', 'structure', 'word order', 'questions', 'statements', 'commands',
    'subject', 'verb', 'object', 'grammar', 'syntax', 'formation'
  ],

  // Strand 3: Vocabulary & Thematic Content
  'Food & Drinks': [
    'food', 'drink', 'eat', 'meal', 'breakfast', 'lunch', 'dinner', 'water', 'juice',
    'milk', 'bread', 'rice', 'banku', 'kenkey', 'fufu', 'soup', 'meat', 'fish'
  ],

  'Animals & Nature': [
    'animals', 'dog', 'cat', 'bird', 'fish', 'cow', 'goat', 'sheep', 'lion', 'elephant',
    'tree', 'river', 'mountain', 'sea', 'sky', 'sun', 'moon', 'rain', 'wind'
  ],

  'Numbers & Time': [
    'numbers', 'one', 'two', 'three', 'four', 'five', 'time', 'clock', 'hour', 'minute',
    'day', 'week', 'month', 'year', 'today', 'tomorrow', 'yesterday'
  ],

  // Strand 4: Reading & Comprehension
  'Reading Comprehension': [
    'reading', 'comprehension', 'understand', 'passage', 'text', 'story', 'meaning',
    'main idea', 'details', 'inference', 'vocabulary', 'context'
  ],

  // Strand 5: Writing & Composition
  'Writing Skills': [
    'writing', 'write', 'letter', 'note', 'message', 'story', 'paragraph', 'sentence',
    'composition', 'describe', 'explain', 'narrate', 'express'
  ]
};

// More intelligent categorization function
function categorizeQuestion(question) {
  const content = `${question.questionText} ${question.options.join(' ')}`.toLowerCase();

  // First, check if the question has explicit topic metadata
  if (question.topics && question.topics.length > 0) {
    const topicMetadata = question.topics[0].toLowerCase();

    // Map metadata topics to our curriculum topics
    if (topicMetadata.includes('communication') || topicMetadata.includes('oral')) {
      if (content.includes('hello') || content.includes('greetings') || content.includes('introduction')) {
        return 'Greetings & Introductions';
      }
      if (content.includes('family') || content.includes('relationship')) {
        return 'Family & Relationships';
      }
      return 'Daily Activities';
    }
    if (topicMetadata.includes('grammar') || topicMetadata.includes('structure')) {
      if (content.includes('noun') || content.includes('pronoun')) {
        return 'Nouns & Pronouns';
      }
      if (content.includes('verb') || content.includes('tense')) {
        return 'Verbs & Tenses';
      }
      return 'Sentence Structure';
    }
    if (topicMetadata.includes('vocabulary') || topicMetadata.includes('theme')) {
      if (content.includes('food') || content.includes('drink') || content.includes('eat')) {
        return 'Food & Drinks';
      }
      if (content.includes('animal') || content.includes('nature') || content.includes('tree')) {
        return 'Animals & Nature';
      }
      if (content.includes('number') || content.includes('time') || content.includes('clock')) {
        return 'Numbers & Time';
      }
      return 'Reading Comprehension';
    }
    if (topicMetadata.includes('writing') || topicMetadata.includes('composition')) {
      return 'Writing Skills';
    }
  }

  // Check partHeader for additional categorization clues
  if (question.partHeader) {
    const partHeader = question.partHeader.toLowerCase();
    if (partHeader.includes('greetings') || partHeader.includes('communication')) {
      return 'Greetings & Introductions';
    }
    if (partHeader.includes('grammar') || partHeader.includes('structure')) {
      return 'Sentence Structure';
    }
    if (partHeader.includes('reading') || partHeader.includes('comprehension')) {
      return 'Reading Comprehension';
    }
    if (partHeader.includes('writing') || partHeader.includes('composition')) {
      return 'Writing Skills';
    }
  }

  // Check paperInstructions for clues
  if (question.paperInstructions) {
    const instructions = question.paperInstructions.toLowerCase();
    if (instructions.includes('greetings') || instructions.includes('communication')) {
      return 'Greetings & Introductions';
    }
    if (instructions.includes('grammar') || instructions.includes('structure')) {
      return 'Sentence Structure';
    }
    if (instructions.includes('reading') || instructions.includes('comprehension')) {
      return 'Reading Comprehension';
    }
    if (instructions.includes('writing') || instructions.includes('composition')) {
      return 'Writing Skills';
    }
  }

  // Specific Ga language pattern matching
  if (content.includes('nii') || content.includes('yoo') || content.includes('ɛɛ') ||
      content.includes('ɔɔ') || content.includes('aa') || content.includes('ii')) {
    // Ga specific phonetic patterns - check context
    if (content.includes('family') || content.includes('mother') || content.includes('father') ||
        content.includes('brother') || content.includes('sister')) {
      return 'Family & Relationships';
    }
    if (content.includes('eat') || content.includes('drink') || content.includes('food') ||
        content.includes('meal') || content.includes('banku') || content.includes('kenkey')) {
      return 'Food & Drinks';
    }
    if (content.includes('animal') || content.includes('dog') || content.includes('cat') ||
        content.includes('bird') || content.includes('fish')) {
      return 'Animals & Nature';
    }
  }

  // Ga cultural and traditional content
  if (content.includes('gamɛi') || content.includes('asateŋ') || content.includes('hɔgbaa') ||
      content.includes('akoshia') || content.includes('abla') || content.includes('ajoa')) {
    return 'Family & Relationships'; // Ga names and family traditions
  }

  if (content.includes('abifao') || content.includes('kpo') || content.includes('jiemɔ') ||
      content.includes('yarafeemɔ') || content.includes('hɔmɔwɔ')) {
    return 'Daily Activities'; // Ga traditional activities and ceremonies
  }

  if (content.includes('maŋkɛ') || content.includes('leebi') || content.includes('shwane') ||
      content.includes('nyɔŋteŋ')) {
    return 'Food & Drinks'; // Ga traditional foods
  }

  // Question patterns
  if (content.includes('what') || content.includes('who') || content.includes('where') ||
      content.includes('when') || content.includes('why') || content.includes('how')) {
    return 'Sentence Structure'; // Question formation
  }

  // Time and numbers
  if (content.includes('time') || content.includes('clock') || content.includes('hour') ||
      content.match(/\b\d+\b/)) {
    return 'Numbers & Time';
  }

  // Fallback to keyword matching with scoring
  const scores = {};

  for (const [topic, keywords] of Object.entries(GA_TOPICS)) {
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

  return bestTopic;
}

async function analyzeAndCategorizeGa() {
  try {
    console.log('🇬🇭 Fetching all Ga questions from Firestore...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'ga')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      questions.push({
        id: doc.id,
        ...data
      });
    });

    console.log(`✅ Found ${questions.length} Ga questions\n`);

    console.log('🤖 Analyzing question content with intelligent categorization...\n');

    const categorized = {};
    const unclassified = [];
    let processed = 0;

    // Initialize categories
    for (const topic of Object.keys(GA_TOPICS)) {
      categorized[topic] = [];
    }

    for (const question of questions) {
      const topic = categorizeQuestion(question);

      if (topic && categorized[topic] !== undefined) {
        categorized[topic].push(question);
      } else {
        unclassified.push(question);
      }

      processed++;
      if (processed % 25 === 0) {
        console.log(`  Processed ${processed}/${questions.length} questions...`);
      }
    }

    console.log('✅ Analysis complete!\n');

    // Create output directory
    const outputDir = path.join('assets', 'ga_questions_by_topic');
    await fs.mkdir(outputDir, { recursive: true });

    // Save categorized questions
    const indexData = { generatedAt: new Date().toISOString(), topics: [] };

    for (const [topic, topicQuestions] of Object.entries(categorized)) {
      const filename = topic.toLowerCase().replace(/[^a-z0-9]/g, '_') + '.json';

      const topicData = {
        topic: topic,
        questions: topicQuestions,
        questionCount: topicQuestions.length
      };

      await fs.writeFile(
        path.join(outputDir, filename),
        JSON.stringify(topicData, null, 2)
      );

      indexData.topics.push({
        name: topic,
        filename: filename,
        questionCount: topicQuestions.length
      });

      console.log(`✅ ${topic}: ${topicQuestions.length} questions`);
    }

    // Save unclassified questions
    const unclassifiedData = {
      topic: 'unclassified',
      questions: unclassified,
      questionCount: unclassified.length
    };

    await fs.writeFile(
      path.join(outputDir, '_unclassified.json'),
      JSON.stringify(unclassifiedData, null, 2)
    );

    // Save index
    await fs.writeFile(
      path.join(outputDir, 'index.json'),
      JSON.stringify(indexData, null, 2)
    );

    // Save classification details
    const classificationDetails = {
      totalQuestions: questions.length,
      categorizedQuestions: questions.length - unclassified.length,
      unclassifiedQuestions: unclassified.length,
      categorizationRate: ((questions.length - unclassified.length) / questions.length * 100).toFixed(1) + '%',
      topicsBreakdown: Object.entries(categorized).map(([topic, questions]) => ({
        topic,
        count: questions.length
      }))
    };

    await fs.writeFile(
      path.join(outputDir, '_classification_details.json'),
      JSON.stringify(classificationDetails, null, 2)
    );

    console.log(`❌ Unclassified: ${unclassified.length} questions\n`);

    console.log('======================================================================');
    console.log('🇬🇭 GA CATEGORIZATION SUMMARY');
    console.log('======================================================================');
    console.log(`Total Ga Questions: ${questions.length}`);
    console.log(`Categorized Questions: ${questions.length - unclassified.length} (${classificationDetails.categorizationRate})`);
    console.log(`Unclassified Questions: ${unclassified.length}`);
    console.log('======================================================================\n');

    console.log(`📄 Files saved to: ${outputDir}`);
    console.log('📋 Topics created:');
    for (const topicData of indexData.topics) {
      if (topicData.questionCount > 0) {
        console.log(`   - ${topicData.name}: ${topicData.questionCount} questions`);
      }
    }

  } catch (error) {
    console.error('❌ Error analyzing Ga questions:', error);
    throw error;
  }
}

// Run the function
analyzeAndCategorizeGa()
  .then(() => {
    console.log('\n🎉 Ga question analysis and categorization completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to analyze Ga questions:', error);
    process.exit(1);
  });