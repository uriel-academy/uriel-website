const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Creative Arts & Design Topics (12 topics based on curriculum strands)
const CREATIVE_ARTS_TOPICS = {
  // Strand 1: Visual Arts
  'Drawing': [
    'drawing', 'draw', 'sketch', 'sketching', 'pencil drawing', 'charcoal',
    'ink drawing', 'line drawing', 'contour drawing', 'perspective drawing',
    'still life drawing', 'figure drawing', 'landscape drawing'
  ],

  'Painting': [
    'painting', 'paint', 'watercolor', 'acrylic', 'oil painting', 'canvas',
    'brush', 'palette', 'pigment', 'color mixing', 'still life painting',
    'landscape painting', 'portrait painting', 'abstract painting'
  ],

  'Sculpture & Modelling': [
    'sculpture', 'modelling', 'clay', 'pottery', 'ceramics', 'carving',
    'wood carving', 'stone carving', 'bronze', 'modeling clay', 'wire sculpture',
    'paper mache', 'plaster', 'mold', 'cast', 'relief', 'freestanding'
  ],

  // Strand 2: Performing Arts
  'Music': [
    'music', 'musical', 'instrument', 'rhythm', 'melody', 'harmony', 'pitch',
    'tempo', 'dynamics', 'notation', 'composition', 'performance', 'concert',
    'orchestra', 'band', 'choir', 'singing', 'vocal'
  ],

  'Dance': [
    'dance', 'dancing', 'choreography', 'movement', 'rhythm', 'steps', 'ballet',
    'traditional dance', 'folk dance', 'modern dance', 'dance forms', 'body movement',
    'expression', 'performance', 'stage', 'costume'
  ],

  'Drama': [
    'drama', 'theatre', 'play', 'acting', 'performance', 'script', 'scene',
    'character', 'dialogue', 'monologue', 'stage', 'props', 'costume', 'makeup',
    'rehearsal', 'production', 'director', 'audience'
  ],

  // Strand 3: Design & Technology
  'Design Process': [
    'design process', 'design thinking', 'brainstorming', 'research', 'planning',
    'prototyping', 'testing', 'evaluation', 'iteration', 'concept', 'idea generation',
    'problem solving', 'creative process', 'design brief', 'specifications'
  ],

  'Craftwork': [
    'craftwork', 'craft', 'handicraft', 'artisan', 'traditional craft', 'weaving',
    'beading', 'basketry', 'textile', 'fabric craft', 'jewelry making', 'pottery',
    'woodwork', 'metalwork', 'leatherwork', 'craft techniques', 'handmade'
  ],

  'Digital Art Basics': [
    'digital art', 'computer art', 'graphic design', 'digital tools', 'software',
    'photoshop', 'illustrator', 'digital painting', 'pixel art', 'vector art',
    'digital media', 'computer graphics', 'animation basics', 'digital design'
  ],

  // Strand 4: Art Appreciation
  'Ghanaian Art Forms': [
    'ghanaian art', 'ghana art', 'traditional ghanaian', 'kente', 'adinkra',
    'ghanaian crafts', 'ghanaian sculpture', 'ghanaian pottery', 'ghanaian textiles',
    'ghanaian masks', 'ghanaian festivals', 'ghanaian culture', 'local art forms'
  ],

  'African Arts & Culture': [
    'african art', 'african culture', 'traditional african', 'african crafts',
    'african sculpture', 'african masks', 'african textiles', 'african pottery',
    'african music', 'african dance', 'african festivals', 'continental art',
    'cultural heritage', 'ethnic art', 'tribal art'
  ],

  'Critiquing Art': [
    'critiquing art', 'art criticism', 'art evaluation', 'art analysis', 'judging art',
    'art appreciation', 'aesthetic judgment', 'art review', 'critique', 'assessment',
    'evaluation criteria', 'art standards', 'quality assessment', 'artistic merit'
  ]
};

// More intelligent categorization function
function categorizeQuestion(question) {
  const content = `${question.questionText} ${question.options.join(' ')}`.toLowerCase();

  // First, check if the question has explicit topic metadata
  if (question.topics && question.topics.length > 0) {
    const topicMetadata = question.topics[0].toLowerCase();

    // Map metadata topics to our curriculum topics
    if (topicMetadata.includes('drawing') || topicMetadata.includes('sketch')) {
      return 'Drawing';
    }
    if (topicMetadata.includes('painting') || topicMetadata.includes('paint')) {
      return 'Painting';
    }
    if (topicMetadata.includes('sculpture') || topicMetadata.includes('modelling')) {
      return 'Sculpture & Modelling';
    }
    if (topicMetadata.includes('music') || topicMetadata.includes('musical')) {
      return 'Music';
    }
    if (topicMetadata.includes('dance') || topicMetadata.includes('dancing')) {
      return 'Dance';
    }
    if (topicMetadata.includes('drama') || topicMetadata.includes('theatre')) {
      return 'Drama';
    }
    if (topicMetadata.includes('design') || topicMetadata.includes('technology')) {
      if (content.includes('digital') || content.includes('computer') || content.includes('software')) {
        return 'Digital Art Basics';
      }
      if (content.includes('craft') || content.includes('handicraft')) {
        return 'Craftwork';
      }
      return 'Design Process';
    }
    if (topicMetadata.includes('appreciation') || topicMetadata.includes('critique')) {
      if (content.includes('ghana') || content.includes('ghanaian')) {
        return 'Ghanaian Art Forms';
      }
      if (content.includes('african') || content.includes('culture')) {
        return 'African Arts & Culture';
      }
      return 'Critiquing Art';
    }
  }

  // Check partHeader for additional categorization clues
  if (question.partHeader) {
    const partHeader = question.partHeader.toLowerCase();
    if (partHeader.includes('drawing') || partHeader.includes('sketch')) {
      return 'Drawing';
    }
    if (partHeader.includes('painting') || partHeader.includes('paint')) {
      return 'Painting';
    }
    if (partHeader.includes('sculpture') || partHeader.includes('modelling')) {
      return 'Sculpture & Modelling';
    }
    if (partHeader.includes('music') || partHeader.includes('musical')) {
      return 'Music';
    }
    if (partHeader.includes('dance') || partHeader.includes('dancing')) {
      return 'Dance';
    }
    if (partHeader.includes('drama') || partHeader.includes('theatre')) {
      return 'Drama';
    }
  }

  // Check paperInstructions for clues
  if (question.paperInstructions) {
    const instructions = question.paperInstructions.toLowerCase();
    if (instructions.includes('drawing') || instructions.includes('sketch')) {
      return 'Drawing';
    }
    if (instructions.includes('painting') || instructions.includes('paint')) {
      return 'Painting';
    }
    if (instructions.includes('sculpture') || instructions.includes('modelling')) {
      return 'Sculpture & Modelling';
    }
  }

  // Fallback to keyword matching with scoring
  const scores = {};

  for (const [topic, keywords] of Object.entries(CREATIVE_ARTS_TOPICS)) {
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

async function analyzeAndCategorizeCreativeArts() {
  try {
    console.log('🎨 Fetching all Creative Arts & Design questions from Firestore...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      questions.push({ id: doc.id, ...doc.data() });
    });

    console.log(`✅ Found ${questions.length} Creative Arts & Design questions\n`);

    console.log('🤖 Analyzing question content with intelligent categorization...\n');

    const categorized = {};
    const unclassified = [];
    const classificationLog = [];

    // Initialize categories
    Object.keys(CREATIVE_ARTS_TOPICS).forEach(topic => {
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
    const baseDir = path.join('assets', 'creative_arts_questions_by_topic');
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
    console.log('📊 CREATIVE ARTS & DESIGN CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Creative Arts & Design Questions: ${questions.length}`);
    console.log(`Categorized Questions: ${questions.length - unclassified.length} (${classificationData.classificationRate}%)`);
    console.log(`Unclassified Questions: ${unclassified.length}`);
    console.log('='.repeat(70));

    console.log('\n📄 Files saved to: assets\\creative_arts_questions_by_topic');
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
analyzeAndCategorizeCreativeArts();