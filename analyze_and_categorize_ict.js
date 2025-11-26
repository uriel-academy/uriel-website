const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// ICT Topics with keywords for classification
const ICT_TOPIC_KEYWORDS = {
  'Introduction To Computers': [
    'computer', 'hardware', 'software', 'input', 'output', 'storage', 'cpu', 'processor',
    'monitor', 'keyboard', 'mouse', 'printer', 'scanner', 'system unit', 'peripheral',
    'digital', 'analog', 'binary', 'data', 'information', 'components'
  ],
  'Basic Typing Skills Development & Keyboard': [
    'typing', 'keyboard', 'keys', 'home row', 'finger', 'wpm', 'speed',
    'touch typing', 'shortcut', 'ctrl', 'alt', 'shift', 'function keys'
  ],
  'Health And Safety In Using ICT Tools': [
    'health', 'safety', 'ergonomic', 'posture', 'rsi', 'eye strain', 'lighting',
    'workstation', 'repetitive', 'injury', 'break', 'ventilation', 'hazard',
    'fire', 'electric', 'safe', 'proper use'
  ],
  'Graphical User Interface (GUI)': [
    'gui', 'graphical', 'interface', 'window', 'icon', 'menu', 'toolbar',
    'desktop', 'taskbar', 'dialog box', 'button', 'pointer', 'cursor',
    'drag', 'drop', 'click', 'double-click', 'right-click', 'scroll'
  ],
  'Word Processing Applications': [
    'word', 'document', 'text', 'format', 'font', 'paragraph', 'alignment',
    'bold', 'italic', 'underline', 'copy', 'paste', 'cut', 'edit',
    'spell check', 'grammar', 'page', 'margin', 'indent', 'microsoft word',
    'wordpad', 'notepad', 'typing'
  ],
  'Ethics Of Using ICTs': [
    'ethics', 'ethical', 'privacy', 'copyright', 'piracy', 'plagiarism',
    'cyberbullying', 'netiquette', 'legal', 'illegal', 'moral', 'right',
    'wrong', 'law', 'intellectual property', 'license', 'responsibility'
  ],
  'The Internet And World Wide Web': [
    'internet', 'web', 'www', 'browser', 'website', 'url', 'http', 'https',
    'search engine', 'google', 'email', 'online', 'download', 'upload',
    'social media', 'chat', 'network', 'wifi', 'connection', 'surf'
  ],
  'Spreadsheet Applications': [
    'spreadsheet', 'excel', 'cell', 'row', 'column', 'formula', 'function',
    'sum', 'average', 'chart', 'graph', 'table', 'calculate', 'worksheet',
    'workbook', 'filter', 'sort', 'data analysis'
  ],
  'File And Folder Management': [
    'file', 'folder', 'directory', 'save', 'open', 'create', 'delete',
    'rename', 'move', 'copy', 'organize', 'path', 'extension', 'drive',
    'windows explorer', 'file manager', 'navigation'
  ],
  'Integrating ICT Into Learning': [
    'learning', 'education', 'teaching', 'student', 'classroom', 'e-learning',
    'online learning', 'virtual', 'presentation', 'powerpoint', 'research',
    'project', 'assignment', 'study', 'educational', 'academic'
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

// Function to classify question into topics
function classifyQuestion(questionText, optionsText = '') {
  const fullText = questionText + ' ' + optionsText;
  const scores = {};
  const matches = {};

  for (const [topic, keywords] of Object.entries(ICT_TOPIC_KEYWORDS)) {
    const result = scoreQuestionForTopic(fullText, keywords);
    scores[topic] = result.score;
    matches[topic] = result.matchedKeywords;
  }

  // Get topics with non-zero scores, sorted by score
  const topicScores = Object.entries(scores)
    .filter(([_, score]) => score > 0)
    .sort((a, b) => b[1] - a[1]);

  // Return top topics (those with highest score, or top 2 if tied)
  if (topicScores.length === 0) return [];

  const topScore = topicScores[0][1];
  const topTopics = topicScores
    .filter(([_, score]) => score >= topScore * 0.7) // Include topics with 70% of top score
    .slice(0, 2) // Max 2 topics per question
    .map(([topic, _]) => topic);

  return topTopics;
}

async function analyzeAndCategorizeICT() {
  try {
    console.log('🔍 Fetching all ICT questions from Firestore...\n');
    
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ict')
      .get();
    
    console.log(`✅ Found ${snapshot.size} ICT questions\n`);
    console.log('🤖 Analyzing question content and auto-categorizing...\n');

    // Group questions by classified topic
    const questionsByTopic = {};
    const unclassifiedQuestions = [];
    const classificationDetails = [];

    Object.keys(ICT_TOPIC_KEYWORDS).forEach(topic => {
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
          preview: data.questionText.substring(0, 100) + '...'
        });
      } else {
        unclassifiedQuestions.push(questionData);
      }
    }

    console.log(`\n✅ Analysis complete!`);

    // Create output directory
    const outputDir = path.join('assets', 'ict_questions_by_topic');
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
      topics: Object.keys(ICT_TOPIC_KEYWORDS).map(topic => ({
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
    console.log('📊 CATEGORIZATION SUMMARY');
    console.log('='.repeat(70));
    console.log(`Total ICT Questions: ${snapshot.size}`);
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
analyzeAndCategorizeICT();
