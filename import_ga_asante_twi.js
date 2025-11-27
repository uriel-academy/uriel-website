// import_ga_asante_twi.js
// Import Ga and Asante Twi as separate subjects (not ghanaianLanguage)
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const args = require('minimist')(process.argv.slice(2));

const saPath = args.serviceAccount || './uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json';
const assetsDir = path.join(__dirname, 'assets', 'ghanaian language');

(async () => {
  try {
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    const db = admin.firestore();
    
    console.log('Starting Ga and Asante Twi import as separate subjects...\n');
    
    // Get all question and answer files
    const files = fs.readdirSync(assetsDir);
    const questionFiles = files.filter(f => f.includes('questions.json'));
    
    let totalImported = 0;
    let batch = db.batch();
    let batchCount = 0;
    
    const stats = {
      ga: 0,
      asanteTwi: 0,
    };
    
    for (const questionFile of questionFiles) {
      const answerFile = questionFile.replace('questions', 'answers');
      
      console.log(`Processing: ${questionFile}`);
      
      const questionsData = JSON.parse(
        fs.readFileSync(path.join(assetsDir, questionFile), 'utf8')
      );
      const answersData = JSON.parse(
        fs.readFileSync(path.join(assetsDir, answerFile), 'utf8')
      );
      
      const year = questionsData.year;
      
      // Determine subject from filename
      let subject = '';
      let docPrefix = '';
      if (questionFile.includes('ga_')) {
        subject = 'ga';
        docPrefix = 'ga';
      } else if (questionFile.includes('asante_twi_')) {
        subject = 'asanteTwi';
        docPrefix = 'asante_twi';
      } else {
        console.log(`  ⚠️  Skipping ${questionFile} - cannot determine subject`);
        continue;
      }
      
      console.log(`  Year: ${year}, Subject: ${subject}`);
      
      // Process multiple choice questions
      const mcQuestions = questionsData.multiple_choice || {};
      const mcAnswers = answersData.multiple_choice || {};
      
      let questionsInFile = 0;
      
      for (const [qKey, qData] of Object.entries(mcQuestions)) {
        const questionNumber = parseInt(qKey.replace('q', ''));
        const docId = `${docPrefix}_${year}_q${questionNumber}`;
        
        // Get the full answer text (e.g., "B. Hɔgbaa")
        const fullAnswer = mcAnswers[qKey] || '';
        
        // Format options with letter prefixes
        const options = qData.possibleAnswers || [];
        
        const questionDoc = {
          id: docId,
          questionText: qData.question || '',
          options: options,
          correctAnswer: fullAnswer, // Store full text like "B. Hɔgbaa"
          type: 'multiple_choice',
          subject: subject, // 'ga' or 'asanteTwi'
          examType: 'bece',
          year: year,
          section: '', // No section needed since they're separate subjects
          questionNumber: questionNumber,
          marks: 1,
          difficulty: 'medium',
          topics: [], // Can add topics later if needed
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'admin_import',
          isActive: true,
        };
        
        const docRef = db.collection('questions').doc(docId);
        batch.set(docRef, questionDoc, { merge: true });
        batchCount++;
        questionsInFile++;
        stats[subject === 'ga' ? 'ga' : 'asanteTwi']++;
        
        // Commit batch every 100 operations to avoid timeout
        if (batchCount >= 100) {
          await batch.commit();
          console.log(`  Committed batch of ${batchCount} questions`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
      }
      
      totalImported += questionsInFile;
      console.log(`  Imported ${questionsInFile} questions from ${questionFile}\n`);
    }
    
    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
      console.log(`  Committed final batch of ${batchCount} questions`);
    }
    
    // Update metadata
    const metadataRef = db.collection('app_metadata').doc('ga_asante_twi_import');
    await metadataRef.set({
      totalQuestions: totalImported,
      subjects: ['ga', 'asanteTwi'],
      gaCount: stats.ga,
      asanteTwiCount: stats.asanteTwi,
      years: [2022, 2023, 2024],
      lastImportDate: admin.firestore.FieldValue.serverTimestamp(),
      importType: 'separate_subjects',
      status: 'completed',
    }, { merge: true });
    
    console.log('\n' + '='.repeat(60));
    console.log('✅ Import completed successfully!');
    console.log(`Total questions imported: ${totalImported}`);
    console.log(`  - Ga: ${stats.ga} questions`);
    console.log(`  - Asante Twi: ${stats.asanteTwi} questions`);
    console.log('Years: 2022, 2023, 2024');
    console.log('='.repeat(60));
    
    process.exit(0);
  } catch (e) {
    console.error('❌ Error during import:', e);
    process.exit(1);
  }
})();
