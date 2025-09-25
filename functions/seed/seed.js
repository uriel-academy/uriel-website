const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'uriel-dev'
  });
}

const db = admin.firestore();

// Sample data for seeding
const subjects = [
  {
    id: 'mathematics',
    name: 'Mathematics',
    category: 'core',
    description: 'Core Mathematics for BECE/WASSCE',
    active: true
  },
  {
    id: 'english',
    name: 'English Language', 
    category: 'core',
    description: 'English Language and Comprehension',
    active: true
  },
  {
    id: 'science',
    name: 'Integrated Science',
    category: 'core', 
    description: 'General Science for BECE',
    active: true
  },
  {
    id: 'social_studies',
    name: 'Social Studies',
    category: 'core',
    description: 'Social Studies and Civic Education',
    active: true
  },
  {
    id: 'physics',
    name: 'Physics',
    category: 'elective',
    description: 'Physics for WASSCE',
    active: true
  },
  {
    id: 'chemistry',
    name: 'Chemistry', 
    category: 'elective',
    description: 'Chemistry for WASSCE',
    active: true
  },
  {
    id: 'biology',
    name: 'Biology',
    category: 'elective',
    description: 'Biology for WASSCE', 
    active: true
  }
];

const sampleQuestions = [
  {
    subjectId: 'mathematics',
    question: 'What is the value of x in the equation 2x + 5 = 15?',
    options: ['5', '7.5', '10', '20'],
    correctAnswer: '5',
    explanation: 'Solving: 2x + 5 = 15, 2x = 10, x = 5',
    difficulty: 'easy',
    topic: 'Algebra',
    year: '2023',
    examType: 'BECE',
    active: true
  },
  {
    subjectId: 'mathematics',
    question: 'Find the area of a circle with radius 7cm. (Use π = 22/7)',
    options: ['154 cm²', '44 cm²', '22 cm²', '308 cm²'],
    correctAnswer: '154 cm²',
    explanation: 'Area = πr² = (22/7) × 7² = (22/7) × 49 = 154 cm²',
    difficulty: 'medium',
    topic: 'Geometry',
    year: '2023',
    examType: 'BECE',
    active: true
  },
  {
    subjectId: 'english',
    question: 'Choose the correct form: "She ____ to school every day."',
    options: ['go', 'goes', 'going', 'gone'],
    correctAnswer: 'goes',
    explanation: 'Third person singular present tense requires "goes"',
    difficulty: 'easy',
    topic: 'Grammar',
    year: '2023',
    examType: 'BECE',
    active: true
  },
  {
    subjectId: 'science',
    question: 'What is the chemical symbol for water?',
    options: ['H₂O', 'CO₂', 'NaCl', 'O₂'],
    correctAnswer: 'H₂O',
    explanation: 'Water consists of 2 hydrogen atoms and 1 oxygen atom',
    difficulty: 'easy',
    topic: 'Chemistry',
    year: '2023',
    examType: 'BECE',
    active: true
  }
];

const sampleSchool = {
  id: 'gh_accra_001',
  name: 'Accra International School',
  location: {
    region: 'Greater Accra',
    district: 'Accra Metropolitan',
    address: '123 Independence Avenue, Accra'
  },
  contact: {
    phone: '+233244000000',
    email: 'info@accraschool.edu.gh',
    website: 'https://accraschool.edu.gh'
  },
  settings: {
    calmMode: true,
    languages: ['en', 'tw'],
    timezone: 'Africa/Accra'
  },
  subscription: {
    plan: 'premium',
    status: 'active',
    expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) // 1 year from now
  },
  active: true
};

const sampleUsers = [
  {
    id: 'student_001',
    role: 'student',
    profile: {
      firstName: 'Kwame',
      lastName: 'Asante',
      email: 'kwame.asante@student.gh',
      grade: 'JHS 3',
      dateOfBirth: '2008-05-15'
    },
    tenant: { schoolId: 'gh_accra_001' },
    entitlements: [],
    badges: { level: 0, points: 0, streak: 0, earned: [] },
    settings: { language: ['en'], calmMode: false }
  },
  {
    id: 'parent_001', 
    role: 'parent',
    profile: {
      firstName: 'Sarah',
      lastName: 'Asante',
      email: 'sarah.asante@parent.gh',
      phone: '+233244111111'
    },
    linkedStudentIds: ['student_001'],
    settings: { 
      notifications: { email: true, sms: true, push: true },
      language: ['en']
    }
  },
  {
    id: 'school_admin_001',
    role: 'school_admin',
    profile: {
      firstName: 'Dr. Emmanuel',
      lastName: 'Mensah',
      email: 'admin@accraschool.edu.gh',
      phone: '+233244222222'
    },
    tenant: { schoolId: 'gh_accra_001' },
    settings: { language: ['en'] }
  },
  {
    id: 'super_admin_001',
    role: 'super_admin',
    profile: {
      firstName: 'System',
      lastName: 'Administrator',
      email: 'admin@urielacademy.com'
    },
    settings: { language: ['en'] }
  }
];

const sampleTextbook = {
  id: 'math_bece_guide',
  title: 'BECE Mathematics Complete Guide',
  subject: 'mathematics',
  grade: 'JHS 3',
  author: 'Ghana Education Service',
  description: 'Comprehensive mathematics guide for BECE preparation',
  chapters: [
    { id: 'ch1', title: 'Number Systems', pages: 25 },
    { id: 'ch2', title: 'Algebra', pages: 30 },
    { id: 'ch3', title: 'Geometry', pages: 35 }
  ],
  fileSize: '15MB',
  format: 'PDF',
  active: true
};

const sampleMockExams = [
  {
    id: 'math_practice_001',
    title: 'Mathematics Practice Test 1',
    subjectId: 'mathematics',
    questionCount: 30,
    duration: 90, // minutes
    difficultyMix: { easy: 0.4, medium: 0.4, hard: 0.2 },
    examType: 'BECE',
    active: true
  },
  {
    id: 'english_practice_001', 
    title: 'English Language Practice Test 1',
    subjectId: 'english',
    questionCount: 50,
    duration: 120,
    difficultyMix: { easy: 0.3, medium: 0.5, hard: 0.2 },
    examType: 'BECE',
    active: true
  }
];

const contentData = {
  affirmations: [
    {
      id: 'aff_001',
      text: 'You are capable of achieving great things.',
      language: 'en',
      category: 'motivation'
    },
    {
      id: 'aff_002', 
      text: 'Wo betumi ayɛ nneɛma akɛse.', // Twi: You can do great things
      language: 'tw',
      category: 'motivation'
    },
    {
      id: 'aff_003',
      text: 'Learning is a journey, not a destination.',
      language: 'en', 
      category: 'learning'
    }
  ]
};

async function seedDatabase() {
  console.log('🌱 Starting database seeding...');
  
  const batch = db.batch();
  let operationCount = 0;

  try {
    // Seed subjects
    console.log('📚 Seeding subjects...');
    for (const subject of subjects) {
      const subjectRef = db.collection('subjects').doc(subject.id);
      batch.set(subjectRef, {
        ...subject,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      operationCount++;
    }

    // Commit subjects first (batch size limit)
    if (operationCount > 0) {
      await batch.commit();
      console.log(`✅ Seeded ${operationCount} subjects`);
    }

    // New batch for questions
    const questionBatch = db.batch();
    operationCount = 0;

    // Seed sample questions (generate more per subject)
    console.log('❓ Seeding past questions...');
    for (const subject of subjects) {
      for (let i = 0; i < 10; i++) { // 10 questions per subject
        const questionId = `${subject.id}_q_${String(i + 1).padStart(3, '0')}`;
        const questionRef = db.collection('pastQuestions').doc(questionId);
        
        // Use template questions and vary them
        const baseQuestion = sampleQuestions.find(q => q.subjectId === subject.id) || sampleQuestions[0];
        const questionData = {
          ...baseQuestion,
          subjectId: subject.id,
          question: `${baseQuestion.question} (Question ${i + 1})`,
          difficulty: ['easy', 'medium', 'hard'][i % 3],
          year: ['2021', '2022', '2023'][i % 3],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        questionBatch.set(questionRef, questionData);
        operationCount++;
      }
    }

    if (operationCount > 0) {
      await questionBatch.commit();
      console.log(`✅ Seeded ${operationCount} past questions`);
    }

    // New batch for school and users
    const userBatch = db.batch();
    operationCount = 0;

    // Seed school
    console.log('🏫 Seeding sample school...');
    const schoolRef = db.collection('schools').doc(sampleSchool.id);
    userBatch.set(schoolRef, {
      ...sampleSchool,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    operationCount++;

    // Seed users
    console.log('👥 Seeding sample users...');
    for (const user of sampleUsers) {
      const userRef = db.collection('users').doc(user.id);
      userBatch.set(userRef, {
        ...user,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      operationCount++;

      // Create user aggregate
      const aggRef = db.collection('aggregates').doc('user').collection(user.id).doc('stats');
      userBatch.set(aggRef, {
        totalAttempts: 0,
        averageScore: 0,
        bestScore: 0,
        streakCurrent: 0,
        streakBest: 0,
        subjectStats: {},
        lastActivity: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      operationCount++;
    }

    if (operationCount > 0) {
      await userBatch.commit();
      console.log(`✅ Seeded school and ${sampleUsers.length} users with aggregates`);
    }

    // New batch for content
    const contentBatch = db.batch();
    operationCount = 0;

    // Seed textbooks
    console.log('📖 Seeding textbooks...');
    const textbookRef = db.collection('textbooks').doc(sampleTextbook.id);
    contentBatch.set(textbookRef, {
      ...sampleTextbook,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    operationCount++;

    // Seed mock exams
    console.log('📝 Seeding mock exams...');
    for (const exam of sampleMockExams) {
      const examRef = db.collection('mockExams').doc(exam.id);
      
      // Generate question IDs for this exam
      const subjectQuestions = Array.from({length: 10}, (_, i) => 
        `${exam.subjectId}_q_${String(i + 1).padStart(3, '0')}`
      );
      
      contentBatch.set(examRef, {
        ...exam,
        questionIds: subjectQuestions.slice(0, Math.min(exam.questionCount, subjectQuestions.length)),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      operationCount++;
    }

    // Seed content (affirmations)
    console.log('💭 Seeding content...');
    for (const affirmation of contentData.affirmations) {
      const affRef = db.collection('content').doc('affirmations').collection('items').doc(affirmation.id);
      contentBatch.set(affRef, {
        ...affirmation,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      operationCount++;
    }

    if (operationCount > 0) {
      await contentBatch.commit();
      console.log(`✅ Seeded textbooks, mock exams, and content`);
    }

    console.log('🎉 Database seeding completed successfully!');
    console.log('\n📊 Summary:');
    console.log(`- ${subjects.length} subjects`);
    console.log(`- ${subjects.length * 10} past questions`);  
    console.log(`- 1 sample school`);
    console.log(`- ${sampleUsers.length} sample users`);
    console.log(`- ${sampleMockExams.length} mock exams`);
    console.log(`- 1 textbook`);
    console.log(`- ${contentData.affirmations.length} affirmations`);

  } catch (error) {
    console.error('❌ Error seeding database:', error);
    process.exit(1);
  }
}

// Run seeder
if (require.main === module) {
  seedDatabase()
    .then(() => {
      console.log('✅ Seeding completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Seeding failed:', error);
      process.exit(1);
    });
}

module.exports = { seedDatabase };