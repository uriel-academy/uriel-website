const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// RME Topics with keywords for classification
const RME_TOPIC_KEYWORDS = {
  // Strand 1: God, His Creation & Attributes
  'Nature of God': [
    'nature of god', 'god nature', 'attributes of god', 'god attributes', 'divine nature',
    'god characteristics', 'god qualities', 'almighty', 'omnipotent', 'omniscient',
    'omnipresent', 'eternal', 'creator', 'sovereign', 'holy', 'merciful', 'loving',
    'just', 'wise', 'transcendent', 'immanent', 'divine being', 'supreme being'
  ],
  'God\'s Creation': [
    'creation', 'god created', 'created by god', 'creation story', 'genesis',
    'six days', 'day one', 'day two', 'day three', 'day four', 'day five', 'day six',
    'seventh day', 'rest', 'adam', 'eve', 'garden of eden', 'heavens', 'earth',
    'light', 'darkness', 'firmament', 'waters', 'dry land', 'plants', 'trees',
    'fruit', 'herbs', 'sun', 'moon', 'stars', 'fish', 'birds', 'animals', 'beasts',
    'cattle', 'creeping things', 'living creatures', 'image of god', 'likeness'
  ],
  'Humanity in God\'s Plan': [
    'humanity', 'god plan', 'god purpose', 'human purpose', 'created in image',
    'dominion', 'stewardship', 'responsibility', 'human dignity', 'worth', 'value',
    'god children', 'relationship with god', 'covenant', 'blessing', 'fruitful',
    'multiply', 'subdue earth', 'care for creation', 'human role', 'god intention'
  ],

  // Strand 2: Morality
  'Moral Values': [
    'moral values', 'ethics', 'morality', 'right wrong', 'good evil', 'virtue',
    'character', 'integrity', 'honesty', 'truthfulness', 'justice', 'fairness',
    'compassion', 'kindness', 'love', 'respect', 'responsibility', 'discipline',
    'self control', 'temperance', 'courage', 'wisdom', 'humility', 'forgiveness',
    'patience', 'tolerance', 'loyalty', 'faithfulness', 'obedience', 'duty'
  ],
  'Decision Making': [
    'decision making', 'choices', 'decisions', 'moral choice', 'ethical decision',
    'right choice', 'wrong choice', 'consequences', 'judgment', 'discernment',
    'wisdom in decisions', 'moral reasoning', 'values based', 'principle',
    'conscience', 'guidance', 'moral dilemma', 'righteous decision', 'godly choice'
  ],
  'Social Responsibilities': [
    'social responsibility', 'community', 'society', 'citizenship', 'duty',
    'obligation', 'service', 'help others', 'care for others', 'neighbour',
    'social justice', 'equality', 'rights', 'freedom', 'democracy', 'law',
    'order', 'peace', 'harmony', 'cooperation', 'unity', 'solidarity', 'charity',
    'philanthropy', 'volunteer', 'contribution', 'social welfare', 'public good'
  ],

  // Strand 3: Religion
  'Christianity': [
    'christianity', 'christian', 'jesus christ', 'bible', 'new testament',
    'old testament', 'gospel', 'salvation', 'redemption', 'grace', 'faith',
    'church', 'sacraments', 'baptism', 'holy communion', 'eucharist', 'prayer',
    'worship', 'scripture', 'ten commandments', 'beatitudes', 'sermon mount',
    'apostles', 'disciples', 'resurrection', 'ascension', 'second coming',
    'heaven', 'hell', 'judgment day', 'kingdom of god'
  ],
  'Islam': [
    'islam', 'muslim', 'allah', 'prophet muhammad', 'quran', 'hadith',
    'five pillars', 'shahada', 'salah', 'zakat', 'hajj', 'ramadan', 'fasting',
    'mosque', 'imam', 'sunna', 'jihad', 'halal', 'haram', 'islamic law',
    'sharia', 'ummah', 'caliph', 'sunnah', 'shiite', 'sunni', 'islamic teachings'
  ],
  'African Traditional Religion': [
    'african traditional religion', 'atr', 'ancestors', 'spirits', 'ancestor worship',
    'traditional african', 'african spirituality', 'supreme being', 'god in african',
    'diviners', 'medicine men', 'chief priest', 'rituals', 'ceremonies', 'taboos',
    'totems', 'clan', 'tribe', 'elders', 'oral tradition', 'myths', 'legends',
    'creation stories', 'sacred places', 'shrines', 'fetish', 'juju', 'masquerades',
    'initiation', 'rites of passage', 'circumcision', 'naming ceremony'
  ],

  // Strand 4: The Family, Society & Nation
  'Family Values': [
    'family values', 'family', 'parents', 'children', 'marriage', 'husband',
    'wife', 'siblings', 'extended family', 'nuclear family', 'love in family',
    'respect parents', 'honour father mother', 'family unity', 'family bond',
    'family responsibility', 'care for family', 'family support', 'family harmony',
    'parenting', 'child rearing', 'family traditions', 'family roles', 'discipline'
  ],
  'National Symbols': [
    'national symbols', 'flag', 'anthem', 'coat of arms', 'national emblem',
    'currency', 'national language', 'independence day', 'heroes day',
    'national colours', 'motto', 'pledge', 'national identity', 'symbols of nation',
    'patriotic symbols', 'national pride', 'unity in diversity', 'national heritage'
  ],
  'Patriotism & Citizenship': [
    'patriotism', 'citizenship', 'national pride', 'love country', 'loyalty nation',
    'citizen duties', 'rights responsibilities', 'good citizen', 'national development',
    'community service', 'vote', 'pay taxes', 'obey laws', 'respect authority',
    'national unity', 'peaceful coexistence', 'tolerance', 'diversity', 'inclusion',
    'democratic values', 'freedom', 'justice', 'equality', 'rule of law'
  ],

  // Strand 5: Worship
  'Forms of Worship': [
    'forms of worship', 'worship', 'praise', 'adoration', 'devotion', 'service to god',
    'liturgy', 'ceremony', 'ritual', 'sacrament', 'offering', 'tithe', 'sacrifice',
    'fellowship', 'communion', 'prayer meeting', 'bible study', 'evangelism',
    'mission', 'ministry', 'spiritual disciplines', 'fasting', 'meditation',
    'contemplation', 'spiritual exercises', 'god service'
  ],
  'Prayer & Devotion': [
    'prayer', 'devotion', 'communication with god', 'talking to god', 'supplication',
    'intercession', 'thanksgiving', 'praise prayer', 'confession', 'petition',
    'adoration prayer', 'lord prayer', 'psalms', 'hymns', 'spiritual songs',
    'quiet time', 'devotional', 'morning prayer', 'evening prayer', 'mealtime prayer',
    'family prayer', 'personal devotion', 'spiritual discipline', 'god relationship'
  ],
  'Festivals & Religious Rituals': [
    'festivals', 'religious festivals', 'rituals', 'ceremonies', 'holy days',
    'feasts', 'celebrations', 'passover', 'pentecost', 'tabernacles', 'christmas',
    'easter', 'good friday', 'ascension', 'advent', 'lent', 'epiphany', 'holy week',
    'eid ul fitr', 'eid ul adha', 'ramadan', 'hajj', 'ashura', 'muharram',
    'traditional festivals', 'harvest festival', 'new yam festival', 'homowo',
    'odwira', 'akwasidae', 'rites of passage', 'initiation rites', 'marriage rites',
    'funeral rites', 'naming ceremony', 'puberty rites', 'burial customs'
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

  for (const [topic, keywords] of Object.entries(RME_TOPIC_KEYWORDS)) {
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

async function analyzeAndCategorizeRME() {
  try {
    console.log('🔍 Fetching all RME questions from Firestore...\n');

    // Fetch all RME questions (both subject codes)
    const snapshot1 = await db.collection('questions')
      .where('subject', '==', 'religiousMoralEducation')
      .get();

    const snapshot2 = await db.collection('questions')
      .where('subject', '==', 'RME')
      .get();

    // Combine both snapshots
    const allDocs = [...snapshot1.docs, ...snapshot2.docs];
    const snapshot = {
      size: allDocs.length,
      docs: allDocs
    };

    console.log(`✅ Found ${snapshot.size} RME questions\n`);
    console.log('🤖 Analyzing question content and auto-categorizing...\n');

    // Group questions by classified topic
    const questionsByTopic = {};
    const unclassifiedQuestions = [];
    const classificationDetails = [];

    Object.keys(RME_TOPIC_KEYWORDS).forEach(topic => {
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
    const outputDir = path.join('assets', 'rme_questions_by_topic');
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
      topics: Object.keys(RME_TOPIC_KEYWORDS).map(topic => ({
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
    console.log('📊 RME CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total RME Questions: ${snapshot.size}`);
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
analyzeAndCategorizeRME();