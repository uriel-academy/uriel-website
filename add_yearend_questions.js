const fs = require('fs');
const path = require('path');

// Year-end assessment questions for each JHS level
const yearEndQuestions = {
  'JHS 1': [
    {
      "id": "ye_q1",
      "questionText": "Identify the noun in the sentence: 'Kofi plays football every day.'",
      "options": {"A": "plays", "B": "Kofi", "C": "every", "D": "day"},
      "correctAnswer": "B",
      "explanation": "Kofi is a proper noun (name of a person).",
      "difficulty": "easy",
      "xpValue": 10
    },
    {
      "id": "ye_q2",
      "questionText": "Which sentence is in the present tense?",
      "options": {"A": "I will go tomorrow", "B": "I went yesterday", "C": "I go every day", "D": "I have gone"},
      "correctAnswer": "C",
      "explanation": "Present tense describes current or habitual actions.",
      "difficulty": "easy",
      "xpValue": 10
    },
    // Generate 38 more questions programmatically
  ],
  'JHS 2': [
    {
      "id": "ye_q1",
      "questionText": "What is a metaphor?",
      "options": {"A": "Direct comparison", "B": "Exaggeration", "C": "Implied comparison", "D": "Sound imitation"},
      "correctAnswer": "C",
      "explanation": "A metaphor is an implied comparison without using 'like' or 'as'.",
      "difficulty": "medium",
      "xpValue": 15
    },
    {
      "id": "ye_q2",
      "questionText": "Which is the correct passive voice: 'The teacher teaches the students'?",
      "options": {"A": "The students teach the teacher", "B": "The students are taught by the teacher", "C": "The teacher is teaching students", "D": "Students taught the teacher"},
      "correctAnswer": "B",
      "explanation": "Passive voice: object becomes subject, verb changes to 'be + past participle'.",
      "difficulty": "medium",
      "xpValue": 15
    },
  ],
  'JHS 3': [
    {
      "id": "ye_q1",
      "questionText": "In BECE English, which skill is tested in Paper 1?",
      "options": {"A": "Creative writing only", "B": "Grammar and comprehension", "C": "Speaking", "D": "Listening"},
      "correctAnswer": "B",
      "explanation": "BECE Paper 1 tests grammar, vocabulary, and comprehension skills.",
      "difficulty": "medium",
      "xpValue": 15
    },
    {
      "id": "ye_q2",
      "questionText": "What is the main purpose of a summary?",
      "options": {"A": "To add more details", "B": "To present main ideas briefly", "C": "To criticize", "D": "To translate"},
      "correctAnswer": "B",
      "explanation": "A summary condenses text to its essential points.",
      "difficulty": "medium",
      "xpValue": 15
    },
  ]
};

// Generate additional questions to reach 40 total
function generateAdditionalQuestions(baseQuestions, level, targetCount = 40) {
  const questions = [...baseQuestions];
  const questionCount = questions.length;
  
  // Generic question templates
  const templates = [
    {
      text: "Choose the correctly spelled word:",
      options: ["recieve", "receive", "receeve", "recive"],
      correct: "B",
      explanation: "'Receive' follows the 'i before e except after c' rule.",
      difficulty: "easy",
      xp: 10
    },
    {
      text: "Identify the verb in: 'The students study hard for exams.'",
      options: ["students", "study", "hard", "exams"],
      correct: "B",
      explanation: "'Study' is the action word (verb) in the sentence.",
      difficulty: "easy",
      xp: 10
    },
    {
      text: "Which punctuation mark ends a question?",
      options: ["Period (.)", "Question mark (?)", "Exclamation (!)", "Comma (,)"],
      correct: "B",
      explanation: "Question marks (?) are used to end interrogative sentences.",
      difficulty: "easy",
      xp: 10
    },
    {
      text: "What is the plural of 'child'?",
      options: ["childs", "children", "childes", "child's"],
      correct: "B",
      explanation: "'Children' is the irregular plural form of 'child'.",
      difficulty: "easy",
      xp: 10
    },
    {
      text: "Identify the adjective: 'The beautiful girl sang sweetly.'",
      options: ["girl", "beautiful", "sang", "sweetly"],
      correct: "B",
      explanation: "'Beautiful' describes the noun 'girl', making it an adjective.",
      difficulty: "easy",
      xp: 10
    }
  ];
  
  for (let i = questionCount; i < targetCount; i++) {
    const template = templates[i % templates.length];
    questions.push({
      id: `ye_q${i + 1}`,
      questionText: template.text,
      options: {
        A: template.options[0],
        B: template.options[1],
        C: template.options[2],
        D: template.options[3]
      },
      correctAnswer: template.correct,
      explanation: template.explanation,
      difficulty: template.difficulty,
      xpValue: template.xp
    });
  }
  
  return questions;
}

// Add year-end questions to each textbook JSON
async function addYearEndQuestions() {
  const textbooksDir = path.join(__dirname, 'assets', 'textbooks');
  const textbookFiles = ['english_jhs_1.json', 'english_jhs_2.json', 'english_jhs_3.json'];
  
  for (const filename of textbookFiles) {
    const filepath = path.join(textbooksDir, filename);
    
    console.log(`\n📖 Processing: ${filename}`);
    
    // Read textbook JSON
    const textbookData = JSON.parse(fs.readFileSync(filepath, 'utf8'));
    const year = textbookData.year;
    
    // Get base questions for this level
    const baseQuestions = yearEndQuestions[year] || yearEndQuestions['JHS 1'];
    
    // Generate 40 questions total
    const allQuestions = generateAdditionalQuestions(baseQuestions, year);
    
    // Add year-end questions to textbook
    textbookData.yearEndQuestions = allQuestions;
    textbookData.totalYearEndQuestions = allQuestions.length;
    
    // Write back to file
    fs.writeFileSync(filepath, JSON.stringify(textbookData, null, 2), 'utf8');
    
    console.log(`✅ Added ${allQuestions.length} year-end questions to ${filename}`);
  }
  
  console.log('\n🎉 All textbooks updated with year-end questions!');
}

addYearEndQuestions().catch(console.error);
