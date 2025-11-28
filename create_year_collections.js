// Script to create MCQ/Theory year collections in Firestore
// Run with: node create_year_collections.js

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.appspot.com'
});

const db = admin.firestore();

async function createYearCollections() {
  console.log('🚀 Creating MCQ/Theory year collections from questions...\n');
  
  // Fetch all questions from main collection
  const questionsSnapshot = await db.collection('questions').get();
  console.log(`📊 Found ${questionsSnapshot.docs.length} questions in main collection`);
  
  // Fetch French questions
  const frenchSnapshot = await db.collection('french_questions').get();
  console.log(`📊 Found ${frenchSnapshot.docs.length} French questions`);
  
  // Combine all docs
  const allDocs = [...questionsSnapshot.docs, ...frenchSnapshot.docs];
  
  // Group by subject + year + type + examType
  const grouped = {};
  
  for (const doc of allDocs) {
    const data = doc.data();
    
    // Skip inactive questions
    if (data.isActive !== true) continue;
    
    // Skip trivia
    if (data.subject === 'trivia') continue;
    
    const subject = data.subject || 'unknown';
    const year = data.year || 'unknown';
    const questionType = data.type || 'multipleChoice'; // Already in correct format
    const examType = data.examType || 'bece';
    
    if (subject === 'unknown' || year === 'unknown') continue;
    
    const key = `${examType}_${subject}_${year}_${questionType}`;
    
    if (!grouped[key]) {
      grouped[key] = {
        subject,
        year,
        questionType: questionType,
        examType,
        questionIds: [],
        count: 0
      };
    }
    
    grouped[key].questionIds.push(doc.id);
    grouped[key].count++;
  }
  
  console.log(`\n📦 Found ${Object.keys(grouped).length} unique year collections\n`);
  
  // Create collections in Firestore
  const batch = db.batch();
  let batchCount = 0;
  const maxBatchSize = 500;
  
  for (const [key, data] of Object.entries(grouped)) {
    // Format subject name for display
    const subjectDisplayName = formatSubjectName(data.subject);
    const typeName = data.questionType === 'essay' ? 'Theory' : 'MCQ';
    const name = `${data.examType.toUpperCase()} ${subjectDisplayName} ${data.year} ${typeName}`;
    
    const collectionDoc = {
      name,
      subject: data.subject,
      examType: data.examType,
      year: String(data.year), // Always store as string
      questionType: data.questionType, // Keep original format (multipleChoice or essay)
      questionIds: data.questionIds,
      questionCount: data.count,
      collectionType: 'year', // Distinguish from 'topic' collections
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = db.collection('questionCollections').doc(key);
    batch.set(docRef, collectionDoc, { merge: true });
    batchCount++;
    
    console.log(`  ✅ ${name} (${data.count} questions)`);
    
    // Commit batch if reaching limit
    if (batchCount >= maxBatchSize) {
      await batch.commit();
      console.log(`\n📤 Committed batch of ${batchCount} collections`);
      batchCount = 0;
    }
  }
  
  // Commit remaining
  if (batchCount > 0) {
    await batch.commit();
    console.log(`\n📤 Committed final batch of ${batchCount} collections`);
  }
  
  console.log('\n✅ All year collections created successfully!');
  
  // Print summary by subject
  console.log('\n📊 Summary by Subject:');
  const subjectSummary = {};
  for (const data of Object.values(grouped)) {
    const subject = formatSubjectName(data.subject);
    if (!subjectSummary[subject]) {
      subjectSummary[subject] = { mcq: 0, theory: 0, total: 0 };
    }
    if (data.questionType === 'essay') {
      subjectSummary[subject].theory++;
    } else {
      subjectSummary[subject].mcq++;
    }
    subjectSummary[subject].total++;
  }
  
  for (const [subject, counts] of Object.entries(subjectSummary)) {
    console.log(`  ${subject}: ${counts.mcq} MCQ + ${counts.theory} Theory = ${counts.total} collections`);
  }
}

function formatSubjectName(subject) {
  const names = {
    'mathematics': 'Mathematics',
    'english': 'English',
    'integratedScience': 'Integrated Science',
    'socialStudies': 'Social Studies',
    'religiousMoralEducation': 'RME',
    'ga': 'Ga',
    'asanteTwi': 'Asante Twi',
    'french': 'French',
    'ict': 'ICT',
    'creativeArts': 'Creative Arts',
    'careerTechnology': 'Career Technology'
  };
  return names[subject] || subject;
}

createYearCollections()
  .then(() => {
    console.log('\n🎉 Done!');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
  });
