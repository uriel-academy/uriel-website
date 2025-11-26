const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// ICT Topics as defined
const ICT_TOPICS = [
  'Introduction To Computers',
  'Basic Typing Skills Development & Keyboard',
  'Health And Safety In Using ICT Tools',
  'Graphical User Interface (GUI)',
  'Word Processing Applications',
  'Ethics Of Using ICTs',
  'The Internet And World Wide Web',
  'Spreadsheet Applications',
  'File And Folder Management',
  'Integrating ICT Into Learning'
];

// Function to normalize topic strings for matching
function normalizeTopicString(topic) {
  return topic.toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

// Function to match question topics to defined topics
function matchTopic(questionTopics, definedTopics) {
  const normalizedDefined = definedTopics.map(normalizeTopicString);
  const matches = [];

  for (const qTopic of questionTopics) {
    const normalized = normalizeTopicString(qTopic);
    
    // Try exact match first
    const exactIndex = normalizedDefined.indexOf(normalized);
    if (exactIndex !== -1) {
      matches.push(definedTopics[exactIndex]);
      continue;
    }

    // Try partial match (if question topic contains or is contained in defined topic)
    for (let i = 0; i < normalizedDefined.length; i++) {
      if (normalized.includes(normalizedDefined[i]) || normalizedDefined[i].includes(normalized)) {
        matches.push(definedTopics[i]);
        break;
      }
    }
  }

  return [...new Set(matches)]; // Remove duplicates
}

async function extractICTQuestionsByTopic() {
  try {
    console.log('🔍 Fetching all ICT questions from Firestore...\n');
    
    // Fetch all ICT questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'ict')
      .get();
    
    console.log(`✅ Found ${snapshot.size} ICT questions\n`);
    
    if (snapshot.empty) {
      console.log('❌ No ICT questions found in database');
      return;
    }

    // Group questions by topic
    const questionsByTopic = {};
    const unmatchedQuestions = [];
    const allTopicsFound = new Set();

    // Initialize topic groups
    ICT_TOPICS.forEach(topic => {
      questionsByTopic[topic] = [];
    });

    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const questionTopics = data.topics || [];
      
      // Track all topics found
      questionTopics.forEach(t => allTopicsFound.add(t));

      // Match question to defined topics
      const matchedTopics = matchTopic(questionTopics, ICT_TOPICS);

      if (matchedTopics.length > 0) {
        matchedTopics.forEach(topic => {
          questionsByTopic[topic].push({
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
            topics: data.topics || [],
            examType: data.examType,
            section: data.section || '',
            imageUrl: data.imageUrl || null,
            imageBeforeQuestion: data.imageBeforeQuestion || null,
            imageAfterQuestion: data.imageAfterQuestion || null,
            optionImages: data.optionImages || null
          });
        });
      } else {
        // No match found
        unmatchedQuestions.push({
          id: doc.id,
          year: data.year,
          questionNumber: data.questionNumber,
          topics: questionTopics
        });
      }
    });

    // Create output directory
    const outputDir = path.join('assets', 'ict_questions_by_topic');
    await fs.mkdir(outputDir, { recursive: true });

    // Save each topic as a separate JSON file
    console.log('📝 Saving questions by topic...\n');
    
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
        
        console.log(`✅ ${topic}: ${questions.length} questions → ${filename}`);
      } else {
        console.log(`⚠️  ${topic}: 0 questions`);
      }
    }

    // Save unmatched questions for review
    if (unmatchedQuestions.length > 0) {
      const unmatchedPath = path.join(outputDir, '_unmatched_topics.json');
      await fs.writeFile(
        unmatchedPath,
        JSON.stringify({
          totalUnmatched: unmatchedQuestions.length,
          questions: unmatchedQuestions
        }, null, 2)
      );
      console.log(`\n⚠️  ${unmatchedQuestions.length} questions with unmatched topics saved to _unmatched_topics.json`);
    }

    // Save all unique topics found
    const allTopicsPath = path.join(outputDir, '_all_topics_found.json');
    await fs.writeFile(
      allTopicsPath,
      JSON.stringify({
        totalUniqueTopics: allTopicsFound.size,
        topics: Array.from(allTopicsFound).sort()
      }, null, 2)
    );

    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 EXTRACTION SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total ICT Questions: ${snapshot.size}`);
    console.log(`Matched Questions: ${snapshot.size - unmatchedQuestions.length}`);
    console.log(`Unmatched Questions: ${unmatchedQuestions.length}`);
    console.log(`Unique Topics Found: ${allTopicsFound.size}`);
    console.log(`\nAll topics found in database:`);
    Array.from(allTopicsFound).sort().forEach(topic => {
      console.log(`  - ${topic}`);
    });
    console.log('='.repeat(60));
    
    console.log(`\n✅ All files saved to: ${outputDir}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the extraction
extractICTQuestionsByTopic();
