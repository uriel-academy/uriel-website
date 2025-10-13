const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function detailedDiagnostic() {
  try {
    console.log('🔍 DETAILED DIAGNOSTIC FOR COUNTRY TRIVIA\n');
    console.log('=' .repeat(60));
    
    // Step 1: Check all trivia questions
    console.log('\n1️⃣ Checking all trivia collection documents...\n');
    const allTrivia = await db.collection('trivia').get();
    console.log(`   Total documents in trivia collection: ${allTrivia.size}`);
    
    // Step 2: Filter by subject=trivia
    console.log('\n2️⃣ Filtering by subject="trivia"...\n');
    const subjectFilter = await db.collection('trivia')
      .where('subject', '==', 'trivia')
      .get();
    console.log(`   Documents with subject="trivia": ${subjectFilter.size}`);
    
    // Step 3: Filter by subject + examType
    console.log('\n3️⃣ Filtering by subject="trivia" AND examType="trivia"...\n');
    const bothFilter = await db.collection('trivia')
      .where('subject', '==', 'trivia')
      .where('examType', '==', 'trivia')
      .get();
    console.log(`   Documents matching both: ${bothFilter.size}`);
    
    // Step 4: Filter by all three
    console.log('\n4️⃣ Filtering by subject + examType + isActive=true...\n');
    const fullFilter = await db.collection('trivia')
      .where('subject', '==', 'trivia')
      .where('examType', '==', 'trivia')
      .where('isActive', '==', true)
      .get();
    console.log(`   Documents with all filters: ${fullFilter.size}`);
    
    // Step 5: Count by triviaCategory
    console.log('\n5️⃣ Analyzing triviaCategory values...\n');
    const categories = {};
    fullFilter.forEach(doc => {
      const cat = doc.data().triviaCategory;
      categories[cat] = (categories[cat] || 0) + 1;
    });
    
    console.log('   Breakdown by triviaCategory:');
    Object.entries(categories).forEach(([cat, count]) => {
      console.log(`     - "${cat}": ${count} questions`);
    });
    
    // Step 6: Check specific Country questions
    console.log('\n6️⃣ Checking Country questions in detail...\n');
    const countryQuestions = [];
    fullFilter.forEach(doc => {
      const data = doc.data();
      if (data.triviaCategory === 'Country') {
        countryQuestions.push({ id: doc.id, data });
      }
    });
    
    console.log(`   Total Country questions: ${countryQuestions.length}`);
    
    if (countryQuestions.length > 0) {
      console.log('\n   Sample Country question:');
      const sample = countryQuestions[0];
      console.log(`     Doc ID: ${sample.id}`);
      console.log(`     Question: "${sample.data.question?.substring(0, 50)}..."`);
      console.log(`     Fields present: ${Object.keys(sample.data).join(', ')}`);
      console.log(`     subject: "${sample.data.subject}"`);
      console.log(`     examType: "${sample.data.examType}"`);
      console.log(`     triviaCategory: "${sample.data.triviaCategory}"`);
      console.log(`     isActive: ${sample.data.isActive}`);
      console.log(`     options: ${JSON.stringify(sample.data.options)}`);
      console.log(`     correctAnswer: "${sample.data.correctAnswer}"`);
    }
    
    // Step 7: Check for case sensitivity issues
    console.log('\n7️⃣ Checking for case sensitivity issues...\n');
    const caseTest = await db.collection('trivia')
      .where('triviaCategory', '==', 'country')  // lowercase
      .get();
    console.log(`   Documents with triviaCategory="country" (lowercase): ${caseTest.size}`);
    
    const caseTest2 = await db.collection('trivia')
      .where('triviaCategory', '==', 'COUNTRY')  // uppercase
      .get();
    console.log(`   Documents with triviaCategory="COUNTRY" (uppercase): ${caseTest2.size}`);
    
    // Step 8: Check for any Country-related questions
    console.log('\n8️⃣ Checking category field (not triviaCategory)...\n');
    const categoryCheck = await db.collection('trivia')
      .where('category', '==', 'Country Capitals')
      .get();
    console.log(`   Documents with category="Country Capitals": ${categoryCheck.size}`);
    
    console.log('\n' + '=' .repeat(60));
    console.log('\n✅ DIAGNOSTIC COMPLETE\n');
    
    if (countryQuestions.length === 194) {
      console.log('🎯 RESULT: All 194 Country questions are properly configured!');
      console.log('   The issue might be:');
      console.log('   - Client-side caching');
      console.log('   - User not authenticated');
      console.log('   - Need to rebuild/redeploy the app');
    } else {
      console.log('⚠️  RESULT: Issue found - not all questions have correct fields');
      console.log(`   Expected: 194 questions, Found: ${countryQuestions.length}`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

detailedDiagnostic();
