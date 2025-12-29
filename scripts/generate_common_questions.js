/**
 * Generate 5,000 Common Student Questions using OpenAI
 * This is a one-time bulk generation to populate the cache
 */

const admin = require('firebase-admin');
const OpenAI = require('openai');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Subject distribution for 5,000 questions
const SUBJECTS = {
  mathematics: 1000,
  integratedScience: 1000,
  english: 800,
  socialStudies: 600,
  french: 400,
  ict: 300,
  religiousMoralEducation: 300,
  creativeArts: 300,
  careerTechnology: 300
};

// Topics per subject
const TOPICS = {
  mathematics: [
    'algebra', 'geometry', 'trigonometry', 'statistics', 'probability',
    'fractions', 'decimals', 'percentages', 'equations', 'graphs',
    'ratios', 'proportions', 'mensuration', 'sets', 'number systems'
  ],
  integratedScience: [
    'cells', 'photosynthesis', 'respiration', 'reproduction', 'genetics',
    'atoms', 'molecules', 'chemical reactions', 'acids and bases', 'energy',
    'forces', 'motion', 'electricity', 'magnetism', 'ecosystems'
  ],
  english: [
    'grammar', 'tenses', 'parts of speech', 'sentence structure', 'punctuation',
    'comprehension', 'essay writing', 'letter writing', 'vocabulary', 'idioms',
    'figures of speech', 'spelling', 'pronunciation', 'reading', 'poetry'
  ],
  socialStudies: [
    'Ghana history', 'government', 'citizenship', 'map reading', 'natural resources',
    'economic activities', 'trade', 'colonialism', 'independence', 'culture',
    'festivals', 'ethnic groups', 'regions', 'climate', 'population'
  ],
  french: [
    'greetings', 'numbers', 'colors', 'family', 'food',
    'verbs', 'pronouns', 'adjectives', 'prepositions', 'tenses'
  ],
  ict: [
    'computer parts', 'software', 'hardware', 'internet', 'email',
    'microsoft word', 'excel', 'powerpoint', 'programming', 'networks'
  ],
  religiousMoralEducation: [
    'values', 'honesty', 'respect', 'responsibility', 'tolerance',
    'religious practices', 'moral lessons', 'ethics', 'community service', 'prayer'
  ],
  creativeArts: [
    'drawing', 'painting', 'sculpture', 'music', 'dance',
    'drama', 'crafts', 'design', 'colors', 'patterns'
  ],
  careerTechnology: [
    'woodwork', 'metalwork', 'sewing', 'cooking', 'farming',
    'business', 'entrepreneurship', 'tools', 'safety', 'planning'
  ]
};

async function generateQuestionsForTopic(subject, topic, count) {
  console.log(`\n🤖 Generating ${count} questions for ${subject} - ${topic}...`);
  
  const prompt = `Generate ${count} common student questions that Ghanaian JHS students typically ask about ${topic} in ${subject}. 

Format each as a complete question that a student would genuinely ask, like:
- "How do I solve simultaneous equations?"
- "What is the difference between mitosis and meiosis?"
- "Can you explain past tense in English?"

Make questions realistic, practical, and at JHS (Junior High School) level for Ghanaian students.

Return as a JSON array of question strings only.`;

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert educator who understands common questions Ghanaian JHS students ask. Generate realistic, practical questions students would genuinely ask.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.8,
    });

    const result = JSON.parse(response.choices[0].message.content);
    const questions = result.questions || [];
    
    console.log(`✅ Generated ${questions.length} questions`);
    return questions;
    
  } catch (error) {
    console.error(`❌ Error generating questions:`, error.message);
    return [];
  }
}

async function generateAnswerForQuestion(question, subject) {
  console.log(`  💬 Generating answer for: "${question.substring(0, 60)}..."`);
  
  const prompt = `You are Uri, an AI tutor for Ghanaian JHS students. Answer this student question clearly and educationally:

"${question}"

Subject context: ${subject}

Provide a clear, concise answer that:
1. Directly answers the question
2. Uses examples relevant to Ghana
3. Is appropriate for JHS level
4. Is encouraging and supportive

Keep the answer under 300 words.`;

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are Uri, a helpful AI tutor for Ghanaian students. Provide clear, educational answers.'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 500,
    });

    const answer = response.choices[0].message.content.trim();
    console.log(`  ✅ Generated answer (${answer.length} chars)`);
    return answer;
    
  } catch (error) {
    console.error(`  ❌ Error generating answer:`, error.message);
    return null;
  }
}

async function saveToCacheAndFile(qaData, subject) {
  // Save to Firestore
  const batch = db.batch();
  let batchCount = 0;
  
  for (const qa of qaData) {
    if (batchCount >= 500) {
      await batch.commit();
      batchCount = 0;
    }
    
    const docRef = db.collection('questionCache').doc();
    batch.set(docRef, {
      question: qa.question,
      answer: qa.answer,
      subject: subject,
      questionLowercase: qa.question.toLowerCase().trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'bulk_generation',
      usageCount: 0,
      lastUsedAt: null,
    });
    
    batchCount++;
  }
  
  if (batchCount > 0) {
    await batch.commit();
  }
  
  // Also save to JSON file as backup
  const filename = `./generated_cache/${subject}_questions.json`;
  fs.mkdirSync('./generated_cache', { recursive: true });
  fs.writeFileSync(filename, JSON.stringify(qaData, null, 2));
  
  console.log(`💾 Saved ${qaData.length} Q&A pairs to Firestore and ${filename}`);
}

async function generateSubjectQuestions(subject, totalCount) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`📚 SUBJECT: ${subject} (${totalCount} questions)`);
  console.log(`${'='.repeat(60)}`);
  
  const topics = TOPICS[subject];
  const questionsPerTopic = Math.ceil(totalCount / topics.length);
  
  const allQA = [];
  
  for (const topic of topics) {
    // Step 1: Generate questions
    const questions = await generateQuestionsForTopic(subject, topic, questionsPerTopic);
    
    // Step 2: Generate answers for each question
    for (const question of questions) {
      const answer = await generateAnswerForQuestion(question, subject);
      
      if (answer) {
        allQA.push({ question, answer, topic });
      }
      
      // Rate limiting: wait 1 second between API calls
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // Save progress after each topic
    if (allQA.length > 0) {
      await saveToCacheAndFile(allQA, subject);
    }
    
    console.log(`\n✅ Completed ${topic}: ${allQA.length} total Q&A pairs so far`);
  }
  
  return allQA;
}

async function main() {
  console.log('🚀 Starting bulk question generation...\n');
  console.log(`Target: ${Object.values(SUBJECTS).reduce((a, b) => a + b, 0)} total questions\n`);
  
  const startTime = Date.now();
  let totalGenerated = 0;
  let totalCost = 0;
  
  for (const [subject, count] of Object.entries(SUBJECTS)) {
    const qa = await generateSubjectQuestions(subject, count);
    totalGenerated += qa.length;
    
    // Estimate cost: ~$0.007 per Q&A pair
    totalCost += qa.length * 0.007;
    
    console.log(`\n📊 Progress: ${totalGenerated} questions generated so far`);
    console.log(`💰 Estimated cost so far: $${totalCost.toFixed(2)}\n`);
  }
  
  const endTime = Date.now();
  const durationMinutes = ((endTime - startTime) / 1000 / 60).toFixed(1);
  
  console.log('\n' + '='.repeat(60));
  console.log('✅ GENERATION COMPLETE!');
  console.log('='.repeat(60));
  console.log(`📝 Total questions generated: ${totalGenerated}`);
  console.log(`⏱️  Time taken: ${durationMinutes} minutes`);
  console.log(`💰 Estimated total cost: $${totalCost.toFixed(2)}`);
  console.log('\n🎉 All questions saved to Firestore and JSON files!');
  
  process.exit(0);
}

// Run the script
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
