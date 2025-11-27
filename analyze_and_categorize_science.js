const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Science Topics with keywords for classification
const SCIENCE_TOPIC_KEYWORDS = {
  // Strand 1: Diversity of Matter
  'Materials': [
    'materials', 'matter', 'substances', 'properties of materials', 'physical properties',
    'chemical properties', 'solids', 'liquids', 'gases', 'states of matter', 'melting',
    'boiling', 'freezing', 'evaporation', 'condensation', 'sublimation', 'density',
    'mass', 'volume', 'texture', 'hardness', 'flexibility', 'conductivity', 'solubility'
  ],
  'Mixtures': [
    'mixtures', 'solutions', 'solute', 'solvent', 'concentration', 'saturated solution',
    'unsaturated solution', 'supersaturated', 'solubility', 'dissolving', 'separating mixtures',
    'filtration', 'evaporation', 'distillation', 'chromatography', 'decantation', 'centrifugation',
    'magnetic separation', 'sieving', 'homogeneous', 'heterogeneous', 'colloids', 'suspensions',
    'emulsions', 'alloys'
  ],
  'Elements & Compounds': [
    'elements', 'compounds', 'periodic table', 'atoms', 'molecules', 'chemical formula',
    'symbols', 'metals', 'non-metals', 'noble gases', 'alkali metals', 'halogens', 'chemical bonds',
    'ionic bonds', 'covalent bonds', 'metallic bonds', 'valency', 'oxidation', 'reduction',
    'chemical reactions', 'reactants', 'products', 'conservation of mass', 'law of conservation'
  ],

  // Strand 2: Cycles
  'The Human Body Systems': [
    'human body', 'body systems', 'digestive system', 'respiratory system', 'circulatory system',
    'cardiovascular', 'nervous system', 'endocrine system', 'skeletal system', 'muscular system',
    'reproductive system', 'excretory system', 'urinary system', 'immune system', 'lymphatic system',
    'organs', 'tissues', 'cells', 'heart', 'lungs', 'brain', 'liver', 'kidneys', 'stomach',
    'intestines', 'blood', 'arteries', 'veins', 'capillaries', 'neurons', 'hormones'
  ],
  'Plants & Photosynthesis': [
    'plants', 'photosynthesis', 'chlorophyll', 'chloroplasts', 'light energy', 'carbon dioxide',
    'water', 'glucose', 'oxygen', 'stomata', 'guard cells', 'xylem', 'phloem', 'roots', 'stems',
    'leaves', 'transpiration', 'osmosis', 'diffusion', 'active transport', 'turgor pressure',
    'wilting', 'germination', 'seedling', 'pollination', 'fertilization', 'tropisms', 'auxins',
    'plant hormones', 'respiration in plants'
  ],
  'Life Cycles': [
    'life cycles', 'reproduction', 'asexual reproduction', 'sexual reproduction', 'mitosis',
    'meiosis', 'gametes', 'zygote', 'embryo', 'fetus', 'gestation', 'puberty', 'menstruation',
    'pollination', 'fertilization', 'seed dispersal', 'germination', 'metamorphosis', 'caterpillar',
    'pupa', 'chrysalis', 'butterfly', 'frog', 'tadpole', 'life stages', 'growth', 'development',
    'aging', 'death', 'food chain', 'food web', 'energy flow', 'trophic levels'
  ],

  // Strand 3: Systems
  'The Solar System': [
    'solar system', 'sun', 'planets', 'mercury', 'venus', 'earth', 'mars', 'jupiter', 'saturn',
    'uranus', 'neptune', 'pluto', 'dwarf planets', 'asteroids', 'comets', 'meteors', 'meteorites',
    'asteroid belt', 'kuiper belt', 'oort cloud', 'gravity', 'orbits', 'revolution', 'rotation',
    'phases of moon', 'lunar eclipse', 'solar eclipse', 'tides', 'seasons', 'equinox', 'solstice',
    'constellations', 'galaxies', 'milky way', 'universe'
  ],
  'Earth Processes': [
    'earth processes', 'rocks', 'minerals', 'igneous rocks', 'sedimentary rocks', 'metamorphic rocks',
    'rock cycle', 'erosion', 'weathering', 'deposition', 'earthquake', 'volcano', 'plate tectonics',
    'continental drift', 'faults', 'folds', 'mountains', 'valleys', 'canyons', 'rivers', 'glaciers',
    'wind', 'waves', 'soil formation', 'soil types', 'soil erosion', 'conservation', 'fossils',
    'geological time', 'dating rocks', 'crust', 'mantle', 'core', 'lithosphere', 'asthenosphere'
  ],
  'Ecosystems': [
    'ecosystems', 'biomes', 'habitats', 'communities', 'populations', 'biotic factors', 'abiotic factors',
    'producers', 'consumers', 'decomposers', 'herbivores', 'carnivores', 'omnivores', 'scavengers',
    'food chains', 'food webs', 'energy pyramids', 'biomass', 'nutrient cycles', 'carbon cycle',
    'water cycle', 'nitrogen cycle', 'oxygen cycle', 'photosynthesis', 'respiration', 'adaptation',
    'natural selection', 'evolution', 'extinction', 'endangered species', 'conservation', 'pollution',
    'deforestation', 'desertification', 'global warming', 'greenhouse effect'
  ],

  // Strand 4: Forces & Energy
  'Energy Forms': [
    'energy', 'forms of energy', 'kinetic energy', 'potential energy', 'thermal energy', 'heat',
    'temperature', 'conduction', 'convection', 'radiation', 'insulators', 'conductors', 'specific heat',
    'latent heat', 'melting', 'boiling', 'freezing', 'evaporation', 'condensation', 'light energy',
    'sound energy', 'electrical energy', 'chemical energy', 'nuclear energy', 'renewable energy',
    'non-renewable energy', 'solar energy', 'wind energy', 'hydroelectric', 'geothermal', 'biomass',
    'fossil fuels', 'coal', 'oil', 'natural gas', 'energy conservation', 'energy efficiency'
  ],
  'Electricity & Magnetism': [
    'electricity', 'electric current', 'voltage', 'resistance', 'ohms law', 'circuits', 'series circuit',
    'parallel circuit', 'switches', 'fuses', 'circuit breakers', 'electromagnets', 'magnets', 'magnetic field',
    'magnetic poles', 'attraction', 'repulsion', 'compass', 'earth magnetic field', 'electromagnetic induction',
    'generators', 'transformers', 'step-up', 'step-down', 'power transmission', 'static electricity',
    'lightning', 'thunderstorms', 'electrostatics', 'charging', 'discharging', 'earthing', 'conductors',
    'insulators', 'semiconductors'
  ],
  'Motion & Forces': [
    'motion', 'forces', 'newtons laws', 'inertia', 'acceleration', 'velocity', 'speed', 'distance',
    'displacement', 'vectors', 'scalars', 'gravity', 'weight', 'mass', 'free fall', 'projectile motion',
    'friction', 'air resistance', 'drag force', 'balanced forces', 'unbalanced forces', 'net force',
    'resultant force', 'tension', 'compression', 'shear force', 'pressure', 'area', 'pascal principle',
    'hydraulics', 'pneumatics', 'levers', 'pulleys', 'gears', 'inclined planes', 'wedges', 'screws',
    'wheel axle', 'work', 'power', 'energy', 'efficiency', 'machines'
  ],

  // Strand 5: Human & Environment
  'Personal Health': [
    'personal health', 'hygiene', 'nutrition', 'balanced diet', 'carbohydrates', 'proteins', 'fats',
    'vitamins', 'minerals', 'water', 'calories', 'malnutrition', 'obesity', 'anemia', 'scurvy', 'rickets',
    'exercise', 'physical fitness', 'mental health', 'stress', 'depression', 'anxiety', 'sleep', 'rest',
    'personal care', 'dental hygiene', 'skin care', 'first aid', 'wounds', 'burns', 'fractures', 'sprains',
    'health education', 'lifestyle diseases', 'prevention', 'health promotion'
  ],
  'Diseases & Prevention': [
    'diseases', 'pathogens', 'bacteria', 'viruses', 'fungi', 'protozoa', 'parasites', 'infection',
    'immunity', 'vaccines', 'immunization', 'antibodies', 'white blood cells', 'lymphocytes', 'phagocytes',
    'antigens', 'allergens', 'allergies', 'autoimmune diseases', 'communicable diseases', 'non-communicable',
    'epidemiology', 'quarantine', 'isolation', 'sanitation', 'sterilization', 'disinfection', 'antibiotics',
    'antivirals', 'transmission', 'vectors', 'mosquitoes', 'tsetse fly', 'malaria', 'typhoid', 'cholera',
    'tuberculosis', 'hiv aids', 'measles', 'chickenpox', 'influenza', 'common cold'
  ],
  'Environmental Conservation': [
    'environmental conservation', 'environment', 'pollution', 'air pollution', 'water pollution',
    'soil pollution', 'noise pollution', 'thermal pollution', 'land pollution', 'plastic pollution',
    'industrial waste', 'sewage', 'effluents', 'emissions', 'greenhouse gases', 'carbon footprint',
    'sustainable development', 'conservation', 'preservation', 'recycling', 'reduce', 'reuse', 'reforestation',
    'afforestation', 'wildlife conservation', 'endangered species', 'biodiversity', 'habitat destruction',
    'overfishing', 'deforestation', 'desertification', 'soil erosion', 'water conservation', 'energy conservation',
    'renewable resources', 'non-renewable resources', 'environmental impact assessment'
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

  for (const [topic, keywords] of Object.entries(SCIENCE_TOPIC_KEYWORDS)) {
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

async function analyzeAndCategorizeScience() {
  try {
    console.log('🔍 Fetching all Science questions from Firestore...\n');

    const snapshot = await db.collection('questions')
      .where('subject', '==', 'integratedScience')
      .get();

    console.log(`✅ Found ${snapshot.size} Science questions\n`);
    console.log('🤖 Analyzing question content and auto-categorizing...\n');

    // Group questions by classified topic
    const questionsByTopic = {};
    const unclassifiedQuestions = [];
    const classificationDetails = [];

    Object.keys(SCIENCE_TOPIC_KEYWORDS).forEach(topic => {
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
    const outputDir = path.join('assets', 'science_questions_by_topic');
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
      topics: Object.keys(SCIENCE_TOPIC_KEYWORDS).map(topic => ({
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
    console.log('📊 SCIENCE CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total Science Questions: ${snapshot.size}`);
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
analyzeAndCategorizeScience();