const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Mathematics Topics (23 topics based on JHS Mathematics curriculum)
const MATHEMATICS_TOPICS = {
  // Strand 1: NUMBER
  'Whole Numbers': [
    'whole numbers', 'integers', 'natural numbers', 'counting numbers', 'positive integers',
    'addition', 'subtraction', 'multiplication', 'division', 'factors', 'multiples',
    'prime numbers', 'composite numbers', 'even numbers', 'odd numbers', 'place value',
    'rounding', 'estimation', 'number patterns', 'sequences', 'series'
  ],

  'Fractions': [
    'fractions', 'fraction', 'numerator', 'denominator', 'proper fraction', 'improper fraction',
    'mixed number', 'equivalent fractions', 'simplifying fractions', 'adding fractions',
    'subtracting fractions', 'multiplying fractions', 'dividing fractions', 'fraction operations',
    'comparing fractions', 'ordering fractions', 'fraction conversion'
  ],

  'Decimals': [
    'decimals', 'decimal', 'decimal places', 'decimal point', 'tenths', 'hundredths', 'thousandths',
    'adding decimals', 'subtracting decimals', 'multiplying decimals', 'dividing decimals',
    'decimal operations', 'rounding decimals', 'terminating decimals', 'recurring decimals',
    'decimal to fraction', 'fraction to decimal'
  ],

  'Percentages': [
    'percentages', 'percentage', 'percent', 'per cent', '%', 'percentage increase', 'percentage decrease',
    'percentage change', 'percentage of', 'finding percentage', 'percentage problems',
    'profit', 'loss', 'discount', 'interest', 'commission', 'tax'
  ],

  'Ratios & Proportions': [
    'ratios', 'ratio', 'proportions', 'proportion', 'ratio problems', 'direct proportion',
    'inverse proportion', 'scale', 'scale drawing', 'map scale', 'ratio simplification',
    'dividing in ratio', 'ratio and proportion', 'proportional division'
  ],

  'Indices & Standard Form': [
    'indices', 'index', 'exponents', 'powers', 'power notation', 'base', 'standard form',
    'scientific notation', 'standard index form', 'laws of indices', 'index laws',
    'multiplying indices', 'dividing indices', 'power of power', 'negative indices',
    'fractional indices', 'zero index'
  ],

  'Sets': [
    'sets', 'set', 'set theory', 'universal set', 'subset', 'proper subset', 'empty set',
    'null set', 'intersection', 'union', 'complement', 'venn diagram', 'set notation',
    'element of set', 'belongs to', 'set operations', 'disjoint sets'
  ],

  // Strand 2: ALGEBRA
  'Algebraic Expressions': [
    'algebraic expressions', 'expression', 'variable', 'constant', 'coefficient', 'term',
    'like terms', 'unlike terms', 'simplifying expressions', 'expanding brackets',
    'factorising', 'algebraic manipulation', 'collecting like terms'
  ],

  'Algebraic Operations': [
    'algebraic operations', 'adding algebraic terms', 'subtracting algebraic terms',
    'multiplying algebraic terms', 'dividing algebraic terms', 'algebraic fractions',
    'simplifying algebraic fractions', 'operations with algebra'
  ],

  'Linear Equations': [
    'linear equations', 'equation', 'solving equations', 'simple equations', 'linear equation',
    'one variable', 'two variables', 'simultaneous equations', 'linear simultaneous equations',
    'elimination method', 'substitution method', 'equation solving'
  ],

  'Inequalities': [
    'inequalities', 'inequality', 'linear inequalities', 'solving inequalities',
    'inequality notation', 'greater than', 'less than', 'greater than or equal',
    'less than or equal', 'inequality graphs', 'inequality regions'
  ],

  'Functions & Relations': [
    'functions', 'function', 'relations', 'relation', 'domain', 'range', 'function notation',
    'mapping', 'one-to-one function', 'many-to-one function', 'function graphs',
    'composite functions', 'inverse functions'
  ],

  'Graphs': [
    'graphs', 'graph', 'coordinate geometry', 'coordinates', 'plotting points',
    'straight line graphs', 'gradient', 'slope', 'y-intercept', 'equation of line',
    'distance formula', 'midpoint formula', 'parallel lines', 'perpendicular lines'
  ],

  // Strand 3: GEOMETRY & MEASUREMENT
  'Plane Geometry': [
    'plane geometry', 'angles', 'angle properties', 'triangle', 'quadrilateral', 'polygon',
    'parallel lines', 'transversal', 'alternate angles', 'corresponding angles',
    'interior angles', 'exterior angles', 'triangle angles', 'quadrilateral angles',
    'angle sum', 'geometric properties'
  ],

  'Circle Geometry': [
    'circle geometry', 'circle', 'circles', 'circumference', 'diameter', 'radius', 'chord',
    'arc', 'sector', 'segment', 'tangent', 'circle theorems', 'angle in circle',
    'cyclic quadrilateral', 'circle properties', 'circle calculations'
  ],

  'Geometric Constructions': [
    'geometric constructions', 'construction', 'constructing', 'compass', 'ruler',
    'bisector', 'perpendicular bisector', 'angle bisector', 'constructing triangles',
    'constructing quadrilaterals', 'locus', 'geometric drawing'
  ],

  'Measurement': [
    'measurement', 'measuring', 'length', 'area', 'volume', 'perimeter', 'surface area',
    'units of measurement', 'metric system', 'conversion', 'scale drawing',
    'measuring instruments', 'accuracy', 'precision'
  ],

  'Transformations & Symmetry': [
    'transformations', 'transformation', 'symmetry', 'reflection', 'rotation', 'translation',
    'enlargement', 'scale factor', 'centre of rotation', 'angle of rotation',
    'line of symmetry', 'rotational symmetry', 'transformational geometry'
  ],

  'Pythagoras\' Theorem': [
    'pythagoras', 'pythagoras theorem', 'pythagorean theorem', 'right-angled triangle',
    'hypotenuse', 'right triangle', 'pythagoras problems', 'distance between points',
    '3-4-5 triangle', 'pythagorean triples'
  ],

  // Strand 4: DATA & PROBABILITY
  'Data Collection': [
    'data collection', 'collecting data', 'survey', 'questionnaire', 'sampling',
    'population', 'sample', 'data gathering', 'primary data', 'secondary data',
    'data sources', 'data collection methods'
  ],

  'Data Representation': [
    'data representation', 'representing data', 'graphs', 'charts', 'bar chart', 'pie chart',
    'line graph', 'histogram', 'frequency table', 'tally chart', 'pictogram',
    'stem and leaf', 'box plot', 'scatter diagram', 'data display'
  ],

  'Measures of Central Tendency': [
    'measures of central tendency', 'mean', 'median', 'mode', 'average', 'range',
    'quartiles', 'interquartile range', 'mean median mode', 'central tendency',
    'statistical measures', 'data analysis'
  ],

  'Probability': [
    'probability', 'probabilities', 'chance', 'likelihood', 'outcome', 'event',
    'sample space', 'favorable outcomes', 'theoretical probability', 'experimental probability',
    'probability scale', 'mutually exclusive', 'independent events', 'tree diagram'
  ]
};

// More intelligent categorization function
function categorizeQuestion(question) {
  const content = `${question.questionText} ${question.options.join(' ')}`.toLowerCase();

  // First, check if the question has explicit topic metadata
  if (question.topics && question.topics.length > 0) {
    const topicMetadata = question.topics[0].toLowerCase();

    // Map metadata topics to our curriculum topics
    if (topicMetadata.includes('number') || topicMetadata.includes('arithmetic')) {
      if (content.includes('fraction')) return 'Fractions';
      if (content.includes('decimal')) return 'Decimals';
      if (content.includes('percent')) return 'Percentages';
      if (content.includes('ratio')) return 'Ratios & Proportions';
      if (content.includes('index') || content.includes('power')) return 'Indices & Standard Form';
      if (content.includes('set')) return 'Sets';
      return 'Whole Numbers';
    }
    if (topicMetadata.includes('algebra')) {
      if (content.includes('expression')) return 'Algebraic Expressions';
      if (content.includes('equation')) return 'Linear Equations';
      if (content.includes('inequality')) return 'Inequalities';
      if (content.includes('function')) return 'Functions & Relations';
      if (content.includes('graph')) return 'Graphs';
      return 'Algebraic Operations';
    }
    if (topicMetadata.includes('geometry') || topicMetadata.includes('measurement')) {
      if (content.includes('circle')) return 'Circle Geometry';
      if (content.includes('construct')) return 'Geometric Constructions';
      if (content.includes('transform')) return 'Transformations & Symmetry';
      if (content.includes('pythagoras')) return 'Pythagoras\' Theorem';
      if (content.includes('measure') || content.includes('area') || content.includes('volume')) return 'Measurement';
      return 'Plane Geometry';
    }
    if (topicMetadata.includes('data') || topicMetadata.includes('probability') || topicMetadata.includes('statistics')) {
      if (content.includes('collect')) return 'Data Collection';
      if (content.includes('represent') || content.includes('graph') || content.includes('chart')) return 'Data Representation';
      if (content.includes('mean') || content.includes('median') || content.includes('mode')) return 'Measures of Central Tendency';
      if (content.includes('probability') || content.includes('chance')) return 'Probability';
      return 'Data Representation';
    }
  }

  // Check partHeader for additional categorization clues
  if (question.partHeader) {
    const partHeader = question.partHeader.toLowerCase();
    if (partHeader.includes('number') || partHeader.includes('arithmetic')) {
      return 'Whole Numbers';
    }
    if (partHeader.includes('algebra')) {
      return 'Algebraic Expressions';
    }
    if (partHeader.includes('geometry')) {
      return 'Plane Geometry';
    }
    if (partHeader.includes('data') || partHeader.includes('statistics')) {
      return 'Data Representation';
    }
  }

  // Check paperInstructions for clues
  if (question.paperInstructions) {
    const instructions = question.paperInstructions.toLowerCase();
    if (instructions.includes('calculate') || instructions.includes('compute')) {
      return 'Whole Numbers';
    }
    if (instructions.includes('solve')) {
      if (content.includes('equation')) return 'Linear Equations';
      if (content.includes('inequality')) return 'Inequalities';
    }
  }

  // Specific mathematics pattern matching
  if (content.includes('calculate') || content.includes('compute') || content.includes('find') ||
      content.includes('determine') || content.includes('evaluate')) {
    if (content.includes('area') || content.includes('volume') || content.includes('perimeter') ||
        content.includes('surface area') || content.includes('circumference') || content.includes('length')) {
      return 'Measurement';
    }
    if (content.includes('probability') || content.includes('chance') || content.includes('likely') ||
        content.includes('sample space') || content.includes('favorable')) {
      return 'Probability';
    }
    if (content.includes('mean') || content.includes('median') || content.includes('mode') ||
        content.includes('average') || content.includes('central tendency')) {
      return 'Measures of Central Tendency';
    }
  }

  // Mathematical symbols and operations
  if (content.includes('=') || content.includes('equation') || content.includes('solve')) {
    if (content.includes('>') || content.includes('<') || content.includes('≥') || content.includes('≤') ||
        content.includes('inequality') || content.includes('inequal')) {
      return 'Inequalities';
    }
    if (content.includes('graph') || content.includes('plot') || content.includes('line') ||
        content.includes('coordinate') || content.includes('point') || content.includes('axis')) {
      return 'Graphs';
    }
    if (content.includes('simultaneous') || content.includes('system') || content.includes('pair')) {
      return 'Algebraic Operations';
    }
    if (content.includes('x') || content.includes('y') || content.includes('variable') ||
        content.includes('unknown') || content.includes('linear')) {
      return 'Linear Equations';
    }
  }

  if (content.includes('graph') || content.includes('plot') || content.includes('coordinate')) {
    return 'Graphs';
  }

  if (content.includes('triangle') || content.includes('angle') || content.includes('parallel')) {
    if (content.includes('right') && content.includes('triangle')) {
      return 'Pythagoras\' Theorem';
    }
    return 'Plane Geometry';
  }

  if (content.includes('circle') || content.includes('radius') || content.includes('diameter')) {
    return 'Circle Geometry';
  }

  // Additional specific patterns for unclassified questions
  if (content.includes('reflect') || content.includes('reflection') || content.includes('rotate') ||
      content.includes('rotation') || content.includes('translate') || content.includes('translation') ||
      content.includes('transform') || content.includes('symmetry') || content.includes('enlarge') ||
      content.includes('scale factor') || content.includes('centre of enlargement') ||
      content.includes('mirror') || content.includes('flip')) {
    return 'Transformations & Symmetry';
  }

  if (content.includes('integer') || content.includes('whole number') || content.includes('natural number') ||
      content.includes('positive') || content.includes('negative') || content.includes('rational') ||
      content.includes('irrational') || content.includes('real number') || content.includes('number type') ||
      content.includes('not an integer') || content.includes('is not an integer')) {
    return 'Whole Numbers';
  }

  if (content.includes('simplify') || content.includes('expand') || content.includes('factor') ||
      content.includes('bracket') || content.includes('expression') || content.includes('term') ||
      content.includes('coefficient') || content.includes('variable') || content.includes('constant') ||
      content.includes('like terms') || content.includes('unlike terms') || content.includes('substitute') ||
      content.includes('ab²') || content.includes('a²b') || content.includes('algebraic simplification')) {
    return 'Algebraic Expressions';
  }

  if (content.includes('table') || content.includes('chart') || content.includes('diagram') ||
      content.includes('represent') || content.includes('display') ||
      content.includes('bar chart') || content.includes('pie chart') || content.includes('histogram')) {
    return 'Data Representation';
  }

  if (content.includes('survey') || content.includes('collect') || content.includes('sample') ||
      content.includes('population') || content.includes('data collection') || content.includes('census')) {
    return 'Data Collection';
  }

  // Vector and coordinate geometry patterns
  if (content.includes('vector') || content.includes('vectors') || content.includes('magnitude') ||
      content.includes('direction') || content.includes('resultant') || content.includes('component') ||
      (content.includes('(') && content.includes(')') && content.includes(',') && content.includes('point'))) {
    return 'Graphs'; // Vectors are typically taught with coordinate geometry
  }

  // Power and index patterns
  if (content.includes('a6') || content.includes('a4') || content.includes('a²') || content.includes('a³') ||
      content.includes('power') || content.includes('exponent') || content.includes('÷') && content.includes('a') ||
      content.includes('index') || content.includes('indices')) {
    return 'Indices & Standard Form';
  }

  // Fraction word problems
  if ((content.includes('1/2') || content.includes('1 2') || content.includes('½')) &&
      (content.includes('gave') || content.includes('gave to') || content.includes('shared') ||
       content.includes('divided') || content.includes('left'))) {
    return 'Fractions';
  }

  // Percentage word problems
  if (content.includes('0.3') || content.includes('30%') || content.includes('percent') ||
      content.includes('income') || content.includes('rent') || content.includes('annual') ||
      content.includes('salary') || content.includes('profit') || content.includes('loss')) {
    return 'Percentages';
  }

  // Decimal evaluation patterns
  if (content.includes('evaluate') || content.includes('calculate') || content.includes('compute')) {
    if (content.includes('0.07') || content.includes('0.02') || content.includes('0.') ||
        content.includes('decimal') || content.includes('×') || content.includes('÷')) {
      return 'Decimals';
    }
  }

  // Division and packing problems
  if (content.includes('packed') || content.includes('boxes') || content.includes('each') ||
      content.includes('contained') || content.includes('fully packed') ||
      content.includes('divided by') || content.includes('divisible by') ||
      content.includes('least number') || content.includes('added to')) {
    return 'Whole Numbers';
  }

  // Age problems
  if (content.includes('years old') || content.includes('old') || content.includes('age') ||
      content.includes('half as old') || content.includes('twice as old') ||
      content.includes('older than') || content.includes('younger than')) {
    return 'Linear Equations';
  }

  // Proportion and cost problems
  if (content.includes('copies') || content.includes('cost') || content.includes('price') ||
      content.includes('each') || content.includes('total') ||
      (content.includes('gh₵') || content.includes('ghc') || content.includes('cedis'))) {
    return 'Ratios & Proportions';
  }

  // Fraction division and complex operations
  if (content.includes('divide') && (content.includes('1 1 2') || content.includes('1 4') ||
      content.includes('fraction') || content.includes('÷'))) {
    return 'Fractions';
  }

  // Word problems with equations
  if (content.includes('subtracted from') || content.includes('multiplied by') ||
      content.includes('result is') || content.includes('final result') ||
      content.includes('certain number') || content.includes('find the number')) {
    return 'Linear Equations';
  }

  // Vector operations with coordinates
  if ((content.includes('r =') || content.includes('t =') || content.includes('u =') || content.includes('v =')) &&
      content.includes('(') && content.includes(')') && content.includes('evaluate')) {
    return 'Graphs';
  }

  // Fallback to keyword matching with scoring
  const scores = {};

  for (const [topic, keywords] of Object.entries(MATHEMATICS_TOPICS)) {
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

async function analyzeAndCategorizeMathematics() {
  try {
    console.log('🔢 Analyzing Mathematics questions...\n');

    const questionsSnapshot = await db.collection('questions')
      .where('subject', '==', 'mathematics')
      .get();

    const questions = [];
    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      questions.push({
        id: doc.id,
        ...data
      });
    });

    console.log(`✅ Found ${questions.length} Mathematics questions\n`);

    console.log('🤖 Analyzing question content with intelligent categorization...\n');

    const categorized = {};
    const unclassified = [];
    let processed = 0;

    // Initialize categories
    for (const topic of Object.keys(MATHEMATICS_TOPICS)) {
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
      if (processed % 100 === 0) {
        console.log(`  Processed ${processed}/${questions.length} questions...`);
      }
    }

    console.log('✅ Analysis complete!\n');

    // Create output directory
    const outputDir = path.join('assets', 'mathematics_questions_by_topic');
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
    console.log('🔢 MATHEMATICS CATEGORIZATION SUMMARY');
    console.log('======================================================================');
    console.log(`Total Mathematics Questions: ${questions.length}`);
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
    console.error('❌ Error analyzing Mathematics questions:', error);
    throw error;
  }
}

// Run the function
analyzeAndCategorizeMathematics()
  .then(() => {
    console.log('\n🎉 Mathematics question analysis and categorization completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Failed to analyze Mathematics questions:', error);
    process.exit(1);
  });