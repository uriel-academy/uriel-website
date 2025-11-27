const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Social Studies Topics with keywords for classification
const SOCIAL_STUDIES_TOPICS = {
  // Strand 1: Environment
  'Our Physical Environment': [
    'physical environment', 'natural environment', 'geography', 'landforms', 'mountains', 'valleys',
    'plains', 'plateaus', 'rivers', 'lakes', 'oceans', 'seas', 'forests', 'deserts', 'climate',
    'weather', 'seasons', 'rainfall', 'temperature', 'humidity', 'atmosphere', 'biosphere',
    'lithosphere', 'hydrosphere', 'natural resources', 'minerals', 'rocks', 'soil', 'vegetation',
    'wildlife', 'ecosystems', 'habitats', 'biodiversity', 'conservation areas', 'national parks'
  ],
  'Human Environment': [
    'human environment', 'human geography', 'population', 'settlement', 'urban', 'rural',
    'cities', 'towns', 'villages', 'housing', 'transportation', 'roads', 'railways', 'airports',
    'ports', 'communication', 'technology', 'infrastructure', 'services', 'amenities', 'utilities',
    'water supply', 'electricity', 'sanitation', 'waste management', 'recreation', 'parks',
    'schools', 'hospitals', 'markets', 'shopping centers', 'human impact', 'urbanization'
  ],
  'Resources & Sustainability': [
    'resources', 'sustainability', 'natural resources', 'renewable resources', 'non-renewable resources',
    'sustainable development', 'conservation', 'preservation', 'resource management', 'environmental protection',
    'deforestation', 'reforestation', 'soil erosion', 'desertification', 'water conservation', 'energy conservation',
    'recycling', 'reduce reuse recycle', 'waste management', 'pollution control', 'climate change',
    'global warming', 'greenhouse effect', 'carbon footprint', 'environmental impact', 'ecotourism',
    'sustainable tourism', 'resource depletion', 'overexploitation', 'biodiversity loss'
  ],

  // Strand 2: Governance, Politics & Stability
  'Rule of Law': [
    'rule of law', 'law', 'justice', 'fairness', 'equality', 'rights', 'responsibilities', 'citizenship',
    'legal system', 'constitution', 'courts', 'judiciary', 'police', 'law enforcement', 'justice system',
    'human rights', 'civil rights', 'legal rights', 'due process', 'fair trial', 'innocent until proven guilty',
    'presumption of innocence', 'legal aid', 'access to justice', 'rule by law', 'law and order',
    'social contract', 'government authority', 'checks and balances', 'separation of powers'
  ],
  'Democracy': [
    'democracy', 'democratic', 'elections', 'voting', 'ballots', 'electoral process', 'universal suffrage',
    'political parties', 'candidates', 'campaigning', 'political freedom', 'freedom of speech', 'freedom of assembly',
    'freedom of press', 'multi-party system', 'opposition parties', 'parliament', 'congress', 'legislature',
    'representation', 'people power', 'popular sovereignty', 'democratic principles', 'civil society',
    'political participation', 'civic education', 'voter education', 'electoral commission', 'free and fair elections'
  ],
  'Local & Central Government': [
    'government', 'local government', 'central government', 'national government', 'federal government',
    'unitary government', 'decentralization', 'local governance', 'district assemblies', 'regional government',
    'ministry', 'departments', 'bureaucracy', 'civil service', 'public administration', 'policy making',
    'legislation', 'executive', 'legislative', 'judicial', 'president', 'prime minister', 'cabinet',
    'ministers', 'governor', 'mayor', 'council', 'assembly members', 'mp', 'member of parliament',
    'constituency', 'ward', 'community', 'grassroots', 'devolution of power'
  ],

  // Strand 3: Social & Economic Development
  'Population': [
    'population', 'demography', 'census', 'population growth', 'birth rate', 'death rate', 'fertility rate',
    'mortality rate', 'life expectancy', 'population density', 'population distribution', 'urban population',
    'rural population', 'migration', 'immigration', 'emigration', 'internal migration', 'international migration',
    'refugees', 'asylum seekers', 'population pyramid', 'age structure', 'dependency ratio', 'working population',
    'youth population', 'aging population', 'population control', 'family planning', 'population policies'
  ],
  'Production & Entrepreneurship': [
    'production', 'entrepreneurship', 'business', 'industry', 'manufacturing', 'agriculture', 'farming',
    'commerce', 'trade', 'services', 'primary sector', 'secondary sector', 'tertiary sector', 'quaternary sector',
    'entrepreneur', 'small business', 'startups', 'innovation', 'risk taking', 'profit', 'loss', 'investment',
    'capital', 'labor', 'land', 'enterprise', 'economic activities', 'productivity', 'efficiency', 'competition',
    'market economy', 'private enterprise', 'public enterprise', 'cooperative', 'joint venture'
  ],
  'Tourism & Development': [
    'tourism', 'development', 'eco-tourism', 'cultural tourism', 'adventure tourism', 'medical tourism',
    'business tourism', 'tourist attractions', 'heritage sites', 'beaches', 'mountains', 'wildlife reserves',
    'national parks', 'museums', 'historical sites', 'festivals', 'cultural events', 'hospitality industry',
    'hotels', 'resorts', 'travel agencies', 'tour operators', 'tourism development', 'sustainable tourism',
    'tourism impact', 'economic benefits', 'cultural preservation', 'community development', 'infrastructure development',
    'job creation', 'foreign exchange', 'tourism promotion', 'tourism policies'
  ],

  // Strand 4: History of Ghana
  'Ancient Ghana': [
    'ancient ghana', 'ghana empire', 'mali empire', 'songhai empire', 'west african empires', 'kumbi saleh',
    'timbuktu', 'mansa musa', 'gold trade', 'salt trade', 'trans-saharan trade', 'islamic influence', 'mali',
    'sunni ali', 'askia muhammad', 'great zimbabwe', 'axum', 'nubia', 'meroe', 'kush', 'african kingdoms',
    'oral traditions', 'griots', 'storytellers', 'pre-colonial africa', 'indigenous systems', 'chieftaincy',
    'traditional rulers', 'council of elders', 'extended family', 'clan system', 'tribal organization'
  ],
  'Colonialism & Independence': [
    'colonialism', 'independence', 'colonial rule', 'british colony', 'gold coast', 'scramble for africa',
    'berlin conference', 'partition of africa', 'indirect rule', 'direct rule', 'colonial administration',
    'colonial economy', 'cash crops', 'cocoa', 'mining', 'railways', 'harbors', 'colonial education',
    'missionary schools', 'nationalism', 'pan-africanism', 'independence movements', 'kwame nkrumah',
    'convention people party', 'cpp', 'positive action', 'boycott', 'strikes', 'civil disobedience',
    'self-government', 'dominion status', 'republic', 'flag independence', '6th march 1957'
  ],
  'Post-Independence Ghana': [
    'post-independence', 'post-colonial', 'first republic', 'second republic', 'third republic', 'fourth republic',
    'military rule', 'coups', 'democratization', 'constitutional rule', 'economic development', 'industrialization',
    'structural adjustment', 'economic recovery', 'poverty reduction', 'education reform', 'health reform',
    'agricultural development', 'mining sector', 'oil discovery', 'ghana@60', 'millennium development goals',
    'sustainable development goals', 'sdgs', 'middle income country', 'emerging economy', 'china-africa relations',
    'regional integration', 'ecowas', 'african union', 'united nations', 'international relations'
  ]
};

// Function to score question against topic keywords
function scoreQuestionForTopic(questionText, keywords) {
  const text = questionText.toLowerCase();
  let score = 0;
  const matchedKeywords = [];

  for (const keyword of keywords) {
    const keywordLower = keyword.toLowerCase();
    if (text.includes(keywordLower)) {
      score++;
      matchedKeywords.push(keyword);
    }
  }

  return { score, matchedKeywords };
}

// Function to classify question into ONE primary topic
function classifyQuestion(questionText, optionsText = '') {
  const fullText = questionText + ' ' + optionsText;
  const scores = {};

  for (const [topic, keywords] of Object.entries(SOCIAL_STUDIES_TOPICS)) {
    const result = scoreQuestionForTopic(fullText, keywords);
    scores[topic] = result.score;
  }

  // Get the topic with highest score
  const topicScores = Object.entries(scores).sort((a, b) => b[1] - a[1]);

  // Return only the top topic (must have at least 1 match)
  if (topicScores.length > 0 && topicScores[0][1] > 0) {
    return [topicScores[0][0]]; // Return as array for consistency
  }

  return []; // No classification
}

async function analyzeAndCategorizeSocialStudies() {
  try {
    console.log('🔍 Fetching all Social Studies questions from Firestore...\n');

    const snapshot = await db.collection('questions')
      .where('subject', '==', 'socialStudies')
      .get();

    console.log(`✅ Found ${snapshot.size} Social Studies questions\n`);
    console.log('🤖 Analyzing question content and auto-categorizing...\n');

    // Group questions by classified topic
    const questionsByTopic = {};
    const unclassifiedQuestions = [];
    const classificationDetails = [];

    Object.keys(SOCIAL_STUDIES_TOPICS).forEach(topic => {
      questionsByTopic[topic] = [];
    });

    let processedCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      processedCount++;

      if (processedCount % 100 === 0) {
        console.log(`  Processed ${processedCount}/${snapshot.size} questions...`);
      }

      // Prepare options text for analysis
      const optionsText = data.options ? data.options.join(' ') : '';

      // Classify the question
      const classifiedTopics = classifyQuestion(data.questionText, optionsText);

      const questionData = {
        id: doc.id,
        questionText: data.questionText,
        type: data.type,
        year: data.year,
        questionNumber: data.questionNumber,
        options: data.options || [],
        correctAnswer: data.correctAnswer,
        explanation: data.explanation || '',
        marks: data.marks || 1,
        difficulty: data.difficulty || 'medium',
        originalTopics: data.topics || [],
        classifiedTopics: classifiedTopics,
        examType: data.examType,
        section: data.section || '',
        imageUrl: data.imageUrl || null,
        imageBeforeQuestion: data.imageBeforeQuestion || null,
        imageAfterQuestion: data.imageAfterQuestion || null,
        optionImages: data.optionImages || null
      };

      if (classifiedTopics.length > 0) {
        classifiedTopics.forEach(topic => {
          questionsByTopic[topic].push(questionData);
        });

        classificationDetails.push({
          id: doc.id,
          year: data.year,
          questionNumber: data.questionNumber,
          classifiedTopics: classifiedTopics,
          preview: (data.questionText || '').substring(0, 100) + '...'
        });
      } else {
        unclassifiedQuestions.push(questionData);
      }
    }

    console.log(`\n✅ Analysis complete!`);

    // Create output directory
    const outputDir = path.join('assets', 'social_studies_questions_by_topic');
    await fs.mkdir(outputDir, { recursive: true });

    // Save each topic as a separate JSON file
    console.log('\n📝 Saving categorized questions...\n');

    let totalCategorized = 0;

    for (const [topic, questions] of Object.entries(questionsByTopic)) {
      if (questions.length > 0) {
        const filename = topic.toLowerCase()
          .replace(/[^a-z0-9\s]/g, '')
          .replace(/\s+/g, '_') + '.json';

        const filepath = path.join(outputDir, filename);

        await fs.writeFile(
          filepath,
          JSON.stringify({
            topic: topic,
            totalQuestions: questions.length,
            questions: questions
          }, null, 2)
        );

        totalCategorized += questions.length;
        console.log(`✅ ${topic}: ${questions.length} questions`);
      } else {
        console.log(`⚠️  ${topic}: 0 questions`);
      }
    }

    // Save classification details
    const detailsPath = path.join(outputDir, '_classification_details.json');
    await fs.writeFile(
      detailsPath,
      JSON.stringify({
        totalClassified: classificationDetails.length,
        classifications: classificationDetails
      }, null, 2)
    );

    // Save unclassified questions
    if (unclassifiedQuestions.length > 0) {
      const unclassifiedPath = path.join(outputDir, '_unclassified.json');
      await fs.writeFile(
        unclassifiedPath,
        JSON.stringify({
          totalUnclassified: unclassifiedQuestions.length,
          questions: unclassifiedQuestions
        }, null, 2)
      );
    }

    // Create index file
    const indexData = {
      generatedAt: new Date().toISOString(),
      totalQuestions: snapshot.size,
      categorizedQuestions: totalCategorized,
      unclassifiedQuestions: unclassifiedQuestions.length,
      topics: Object.keys(SOCIAL_STUDIES_TOPICS).map(topic => ({
        name: topic,
        questionCount: questionsByTopic[topic].length,
        filename: topic.toLowerCase().replace(/[^a-z0-9\s]/g, '').replace(/\s+/g, '_') + '.json'
      }))
    };

    await fs.writeFile(
      path.join(outputDir, 'index.json'),
      JSON.stringify(indexData, null, 2)
    );

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log('📊 SOCIAL STUDIES CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Social Studies Questions: ${snapshot.size}`);
    console.log(`Categorized Questions: ${totalCategorized} (${((totalCategorized/snapshot.size)*100).toFixed(1)}%)`);
    console.log(`Unclassified Questions: ${unclassifiedQuestions.length}`);
    console.log('\nQuestions per Topic:');
    Object.entries(questionsByTopic)
      .sort((a, b) => b[1].length - a[1].length)
      .forEach(([topic, questions]) => {
        if (questions.length > 0) {
          console.log(`  ${topic}: ${questions.length}`);
        }
      });
    console.log('='.repeat(70));

    console.log(`\n✅ All files saved to: ${outputDir}`);
    console.log(`\n📄 Files created:`);
    console.log(`   - index.json (metadata)`);
    console.log(`   - _classification_details.json (classification log)`);
    if (unclassifiedQuestions.length > 0) {
      console.log(`   - _unclassified.json (${unclassifiedQuestions.length} unclassified questions)`);
    }
    console.log(`   - ${Object.values(questionsByTopic).filter(q => q.length > 0).length} topic files`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the analysis
analyzeAndCategorizeSocialStudies();