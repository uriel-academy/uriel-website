// Direct Firestore import for RME questions
const admin = require('firebase-admin');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    projectId: 'uriel-academy-41fb0'
  });
} catch (error) {
  console.log('Firebase already initialized or error:', error.message);
}

const db = admin.firestore();

// RME Questions Data (BECE 1999)
const rmeQuestions = [
  {
    id: 'rme_1999_q1',
    questionText: 'According to Christian teaching, God created man and woman on the',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    examType: 'bece',
    year: '1999',
    section: 'A',
    questionNumber: 1,
    options: ['A. 1st day', 'B. 2nd day', 'C. 3rd day', 'D. 5th day', 'E. 6th day'],
    correctAnswer: 'E',
    explanation: 'According to Genesis, God created man and woman on the 6th day.',
    marks: 1,
    difficulty: 'easy',
    topics: ['Christianity', 'Creation'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    createdBy: 'system_import',
    isActive: true,
  },
  {
    id: 'rme_1999_q2',
    questionText: 'Palm Sunday is observed by Christians to remember the',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    examType: 'bece',
    year: '1999',
    section: 'A',
    questionNumber: 2,
    options: [
      'A. birth and baptism of Christ',
      'B. resurrection and appearance of Christ',
      'C. joyful journey of Christ into Jerusalem',
      'D. baptism of the Holy Spirit',
      'E. last supper and sacrifice of Christ'
    ],
    correctAnswer: 'C',
    explanation: 'Palm Sunday commemorates Jesus triumphant entry into Jerusalem.',
    marks: 1,
    difficulty: 'easy',
    topics: ['Christianity', 'Jesus Christ'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    createdBy: 'system_import',
    isActive: true,
  },
  {
    id: 'rme_1999_q3',
    questionText: 'God gave Noah and his people the rainbow to remember',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    examType: 'bece',
    year: '1999',
    section: 'A',
    questionNumber: 3,
    options: [
      'A. the floods which destroyed the world',
      'B. the disobedience of the idol worshippers',
      'C. that God would not destroy the world with water again',
      'D. the building of the ark',
      'E. the usefulness of the heavenly bodies'
    ],
    correctAnswer: 'C',
    explanation: 'The rainbow was Gods covenant sign that He would never again destroy the earth by flood.',
    marks: 1,
    difficulty: 'easy',
    topics: ['Christianity', 'Noah', 'Covenant'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    createdBy: 'system_import',
    isActive: true,
  },
  {
    id: 'rme_1999_q4',
    questionText: 'All the religions in Ghana believe in',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    examType: 'bece',
    year: '1999',
    section: 'A',
    questionNumber: 4,
    options: [
      'A. Jesus Christ',
      'B. the Bible',
      'C. the Prophet Muhammed',
      'D. the Rain god',
      'E. the Supreme God'
    ],
    correctAnswer: 'E',
    explanation: 'All major religions in Ghana acknowledge a Supreme Being/God.',
    marks: 1,
    difficulty: 'easy',
    topics: ['Comparative Religion', 'Supreme Being'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    createdBy: 'system_import',
    isActive: true,
  },
  {
    id: 'rme_1999_q5',
    questionText: 'The Muslim prayers observed between Asr and Isha is',
    type: 'multipleChoice',
    subject: 'religiousMoralEducation',
    examType: 'bece',
    year: '1999',
    section: 'A',
    questionNumber: 5,
    options: [
      'A. Zuhr',
      'B. Jumu\'ah',
      'C. Idd',
      'D. Subhi',
      'E. Maghrib'
    ],
    correctAnswer: 'E',
    explanation: 'Maghrib prayer is observed between Asr and Isha prayers.',
    marks: 1,
    difficulty: 'easy',
    topics: ['Islam', 'Prayer', 'Salah'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    createdBy: 'system_import',
    isActive: true,
  }
];

async function importRMEQuestions() {
  try {
    console.log('🚀 Starting RME questions import...');
    
    const batch = db.batch();
    let importedCount = 0;
    
    for (const question of rmeQuestions) {
      const docRef = db.collection('questions').doc(question.id);
      batch.set(docRef, question);
      importedCount++;
      console.log(`📝 Added question ${question.questionNumber}: ${question.questionText.substring(0, 50)}...`);
    }
    
    await batch.commit();
    console.log(`✅ Successfully imported ${importedCount} RME questions!`);
    
    // Verify import
    const verifySnapshot = await db.collection('questions')
      .where('subject', '==', 'religiousMoralEducation')
      .get();
    
    console.log(`🔍 Verification: Found ${verifySnapshot.docs.length} RME questions in database`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error importing RME questions:', error);
    process.exit(1);
  }
}

importRMEQuestions();