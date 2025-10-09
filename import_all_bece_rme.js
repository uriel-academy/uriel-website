const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Years to import
const years = [
  '1999', '2000', '2001', '2002_a', '2003', '2004', '2005', '2006', '2007',
  '2008', '2009', '2011', '2012', '2013', '2014', '2015', '2016',
  '2017', '2018', '2019', '2020', '2021', '2022'
];

async function importRMEQuestions() {
  console.log('🚀 Starting BECE RME Questions Import (1999-2022)...\n');
  
  let totalImported = 0;
  const importResults = [];
  
  for (const yearFile of years) {
    try {
      const year = yearFile.replace('_a', ''); // Handle 2002_a
      const section = yearFile.includes('_a') ? 'A' : '';
      
      const questionsPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', `bece_${yearFile}_questions.json`);
      const answersPath = path.join(__dirname, 'assets', 'bece_rme_1999_2022', `bece_${yearFile}_answers.json`);
      
      if (!fs.existsSync(questionsPath) || !fs.existsSync(answersPath)) {
        console.log(`⚠️  Skipping ${year} - Files not found`);
        continue;
      }
      
      const questionsData = JSON.parse(fs.readFileSync(questionsPath, 'utf8'));
      const answersData = JSON.parse(fs.readFileSync(answersPath, 'utf8'));
      
      console.log(`📝 Processing ${year}${section ? ` Section ${section}` : ''}...`);
      
      const batch = db.batch();
      let yearImportCount = 0;
      
      // Access the multiple_choice section
      const multipleChoiceQuestions = questionsData.multiple_choice || {};
      const multipleChoiceAnswers = answersData.multiple_choice || {};
      
      // Get all question keys (q1, q2, etc.)
      const questionKeys = Object.keys(multipleChoiceQuestions).filter(key => key.startsWith('q'));
      
      for (const questionKey of questionKeys) {
        const questionData = multipleChoiceQuestions[questionKey];
        const correctAnswer = multipleChoiceAnswers[questionKey];
        
        if (!questionData || !correctAnswer) {
          console.warn(`  ⚠️  Missing data for ${questionKey} in ${year}`);
          continue;
        }
        
        const questionNumber = parseInt(questionKey.substring(1));
        const docId = `rme_${year}${section ? `_${section.toLowerCase()}` : ''}_q${questionNumber}`;
        
        const questionDoc = {
          id: docId,
          questionText: questionData.question,
          type: 'multipleChoice',
          subject: 'religiousMoralEducation',
          subjectName: 'Religious And Moral Education',
          subjectCode: 'RME',
          examType: 'bece',
          examName: 'Basic Education Certificate Examination',
          year: year,
          section: section || 'A',
          questionNumber: questionNumber,
          options: questionData.possibleAnswers || [],
          correctAnswer: correctAnswer,
          explanation: `BECE ${year} RME Question ${questionNumber}`,
          marks: 1,
          difficulty: 'medium',
          topics: ['Religious And Moral Education', 'BECE', year],
          tags: ['rme', 'bece', year, 'past-question'],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'system_import_2024',
          isActive: true,
          isPremium: false,
          metadata: {
            source: `BECE ${year} RME`,
            importDate: new Date().toISOString(),
            verified: true,
            version: '2.0'
          }
        };
        
        const docRef = db.collection('questions').doc(docId);
        batch.set(docRef, questionDoc, { merge: false });
        yearImportCount++;
      }
      
      // Commit batch for this year
      await batch.commit();
      totalImported += yearImportCount;
      
      const result = {
        year: year,
        section: section,
        imported: yearImportCount,
        status: 'success'
      };
      
      importResults.push(result);
      console.log(`  ✅ Imported ${yearImportCount} questions for ${year}${section ? ` Section ${section}` : ''}`);
      
    } catch (error) {
      console.error(`  ❌ Error importing ${yearFile}:`, error.message);
      importResults.push({
        year: yearFile,
        imported: 0,
        status: 'failed',
        error: error.message
      });
    }
  }
  
  // Update metadata
  try {
    console.log('\n📊 Updating metadata...');
    await db.collection('app_metadata').doc('content').set({
      availableYears: admin.firestore.FieldValue.arrayUnion(...years.map(y => y.replace('_a', ''))),
      availableSubjects: admin.firestore.FieldValue.arrayUnion('Religious And Moral Education', 'RME'),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      rmeQuestionsImported: true,
      rmeQuestionsCount: totalImported,
      rmeYears: years.map(y => y.replace('_a', '')),
      importHistory: admin.firestore.FieldValue.arrayUnion({
        date: new Date().toISOString(),
        type: 'BECE RME 1999-2022',
        count: totalImported,
        results: importResults
      })
    }, { merge: true });
    console.log('  ✅ Metadata updated');
  } catch (error) {
    console.error('  ❌ Error updating metadata:', error.message);
  }
  
  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📈 IMPORT SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Questions Imported: ${totalImported}`);
  console.log(`Years Processed: ${importResults.length}`);
  console.log('\nDetailed Results:');
  importResults.forEach(result => {
    const status = result.status === 'success' ? '✅' : '❌';
    console.log(`  ${status} ${result.year}${result.section ? ` Section ${result.section}` : ''}: ${result.imported} questions`);
  });
  console.log('='.repeat(60));
  console.log('\n🎉 Import process completed!');
  
  process.exit(0);
}

// Run the import
importRMEQuestions().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
