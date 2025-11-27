const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Career Technology Topics (15 topics based on curriculum strands)
const CAREER_TECHNOLOGY_TOPICS = {
  // Strand 1: Personal & Career Development
  'Personal Competencies': [
    'personal competencies', 'personal skills', 'self development', 'character development',
    'personal qualities', 'life skills', 'personal growth', 'attitude', 'motivation',
    'self confidence', 'responsibility', 'discipline', 'time management', 'goal setting',
    'confident', 'dedicated', 'determined', 'innovative', 'entrepreneur', 'young entrepreneur',
    'researching', 'improve product', 'skills', 'change', 'establishment'
  ],

  'Career Choices': [
    'career choices', 'career planning', 'job selection', 'career paths', 'occupation',
    'vocation', 'profession', 'career guidance', 'job opportunities', 'work options',
    'career decision', 'future jobs', 'employment choices', 'career', 'job', 'work',
    'employment', 'profession', 'occupation', 'vocation'
  ],

  'Work Ethics': [
    'work ethics', 'professional ethics', 'work attitude', 'punctuality', 'reliability',
    'honesty', 'integrity', 'teamwork', 'cooperation', 'respect', 'work habits',
    'professional conduct', 'work values', 'job ethics', 'ethics', 'attitude', 'conduct',
    'values', 'respect', 'honesty', 'integrity', 'punctuality', 'reliability'
  ],

  // Strand 2: Sewing & Clothing
  'Tools & Equipment': [
    'sewing tools', 'sewing equipment', 'sewing machine', 'needles', 'threads',
    'scissors', 'measuring tools', 'pins', 'irons', 'pressing equipment',
    'sewing accessories', 'fabric tools', 'tailoring tools', 'tools', 'equipment',
    'machine', 'needles', 'threads', 'scissors', 'measuring', 'pins', 'irons',
    'pressing', 'accessories', 'tailoring'
  ],

  'Basic Stitches': [
    'basic stitches', 'running stitch', 'back stitch', 'hemming', 'seam',
    'stitch types', 'hand stitches', 'machine stitches', 'sewing techniques',
    'stitching methods', 'seam finishes', 'edge finishes', 'stitches', 'stitch',
    'hemming', 'seam', 'sewing techniques', 'stitching', 'finishes', 'edge'
  ],

  'Garment Construction': [
    'garment construction', 'pattern making', 'cutting fabric', 'sewing garments',
    'dressmaking', 'clothing construction', 'garment assembly', 'tailoring',
    'sewing patterns', 'fabric joining', 'garment finishing', 'garment', 'construction',
    'pattern', 'cutting', 'fabric', 'dressmaking', 'clothing', 'assembly', 'tailoring',
    'patterns', 'joining', 'finishing', 'freehand cutting', 'texture of fabric',
    'outfit', 'wedding'
  ],

  // Strand 3: Food & Nutrition
  'Ingredients & Tools': [
    'food ingredients', 'kitchen tools', 'cooking utensils', 'measuring tools',
    'kitchen equipment', 'food preparation tools', 'baking tools', 'cooking appliances',
    'ingredients', 'food items', 'kitchen gadgets', 'ingredients', 'tools', 'utensils',
    'measuring', 'equipment', 'preparation', 'baking', 'appliances', 'gadgets'
  ],

  'Meal Planning': [
    'meal planning', 'menu planning', 'nutrition planning', 'balanced diet',
    'meal preparation', 'food planning', 'dietary planning', 'nutritional meals',
    'meal organization', 'food budgeting', 'meal', 'planning', 'menu', 'nutrition',
    'balanced diet', 'dietary', 'nutritional', 'organization', 'budgeting',
    'foods in season', 'cost', 'meal is readily available', 'preserved'
  ],

  'Food Preparation': [
    'food preparation', 'cooking methods', 'food processing', 'meal cooking',
    'kitchen operations', 'food handling', 'cooking techniques', 'food safety',
    'culinary skills', 'cooking procedures', 'preparation', 'cooking', 'processing',
    'handling', 'techniques', 'safety', 'culinary', 'procedures', 'kitchen operations'
  ],

  // Strand 4: Home Management
  'Cleaning & Maintenance': [
    'cleaning', 'house cleaning', 'maintenance', 'home upkeep', 'household cleaning',
    'cleaning methods', 'maintenance work', 'home care', 'cleaning techniques',
    'household maintenance', 'domestic cleaning', 'cleaning', 'maintenance', 'upkeep',
    'household', 'methods', 'work', 'care', 'techniques', 'domestic'
  ],

  'Safety at Home': [
    'home safety', 'household safety', 'safety measures', 'accident prevention',
    'home security', 'safety precautions', 'domestic safety', 'home hazards',
    'safety practices', 'emergency preparedness', 'safety', 'accident', 'prevention',
    'security', 'precautions', 'hazards', 'practices', 'emergency', 'preparedness'
  ],

  'Household Resources': [
    'household resources', 'home budgeting', 'resource management', 'family resources',
    'household finances', 'resource allocation', 'home economics', 'domestic resources',
    'family budgeting', 'household planning', 'resources', 'budgeting', 'management',
    'family', 'finances', 'allocation', 'economics', 'domestic', 'planning'
  ],

  // Strand 5: Materials Technology
  'Simple Projects': [
    'simple projects', 'basic projects', 'craft projects', 'material projects',
    'construction projects', 'woodwork projects', 'metalwork projects', 'design projects',
    'project work', 'practical projects', 'projects', 'craft', 'material', 'construction',
    'woodwork', 'metalwork', 'design', 'practical'
  ],

  'Basic Repairs': [
    'basic repairs', 'repairs', 'maintenance repairs', 'fixing', 'mending',
    'repair work', 'restoration', 'repair techniques', 'maintenance work',
    'troubleshooting', 'repair skills', 'repairs', 'maintenance', 'fixing', 'mending',
    'restoration', 'techniques', 'troubleshooting', 'skills'
  ],

  'Craft Production': [
    'craft production', 'craft making', 'handicrafts', 'artisan work', 'craft items',
    'craft techniques', 'production methods', 'craft skills', 'creative production',
    'craft manufacturing', 'handmade items', 'craft', 'production', 'making', 'handicrafts',
    'artisan', 'items', 'techniques', 'methods', 'skills', 'creative', 'manufacturing',
    'handmade'
  ]
};

function categorizeQuestion(question) {
  const content = `${question.question} ${question.options.join(' ')}`.toLowerCase();

  for (const [topic, keywords] of Object.entries(CAREER_TECHNOLOGY_TOPICS)) {
    for (const keyword of keywords) {
      if (content.includes(keyword.toLowerCase())) {
        return topic;
      }
    }
  }

  return null; // Unclassified
}

async function analyzeAndCategorizeCareerTechnology() {
  try {
    console.log('🔍 Fetching all Career Technology questions from Firestore...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'careerTechnology')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      questions.push({ id: doc.id, ...doc.data() });
    });

    console.log(`✅ Found ${questions.length} Career Technology questions\n`);

    console.log('🤖 Analyzing question content and auto-categorizing...\n');

    const categorized = {};
    const unclassified = [];
    const classificationLog = [];

    // Initialize categories
    Object.keys(CAREER_TECHNOLOGY_TOPICS).forEach(topic => {
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
          reason: 'Keyword match'
        });
      } else {
        unclassified.push(question);
        classificationLog.push({
          questionId: question.id,
          topic: 'unclassified',
          reason: 'No keyword match'
        });
      }

      processed++;
      if (processed % 100 === 0) {
        console.log(`  Processed ${processed}/${questions.length} questions...`);
      }
    }

    console.log('\n✅ Analysis complete!\n');

    // Create directory for categorized questions
    const baseDir = path.join('assets', 'career_technology_questions_by_topic');
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
    console.log('📊 CAREER TECHNOLOGY CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Career Technology Questions: ${questions.length}`);
    console.log(`Categorized Questions: ${questions.length - unclassified.length} (${classificationData.classificationRate}%)`);
    console.log(`Unclassified Questions: ${unclassified.length}`);
    console.log('='.repeat(70));

    console.log('\n📄 Files saved to: assets\\career_technology_questions_by_topic');
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
analyzeAndCategorizeCareerTechnology();