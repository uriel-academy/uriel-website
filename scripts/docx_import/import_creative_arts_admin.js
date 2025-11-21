const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('c:\\uriel_mainapp\\uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://uriel-academy-41fb0.firebaseio.com'
  });
}

const db = admin.firestore();

async function importCreativeArtsQuestions() {
  try {
    console.log('🚀 Starting Creative Arts and Design questions import...');

    // Read the processed CAD question files
    const cad2024Path = path.join(__dirname, 'output_cad_processed', 'bece_creative_arts_2024_questions.json');
    const cad2025Path = path.join(__dirname, 'output_cad_processed', 'bece_creative_arts_2025_questions.json');

    console.log('📖 Reading question files...');
    const cad2024Questions = JSON.parse(fs.readFileSync(cad2024Path, 'utf8'));
    const cad2025Questions = JSON.parse(fs.readFileSync(cad2025Path, 'utf8'));

    console.log(`📊 Found ${cad2024Questions.length} questions for 2024`);
    console.log(`📊 Found ${cad2025Questions.length} questions for 2025`);

    // Combine all questions
    const allQuestions = [...cad2024Questions, ...cad2025Questions];
    console.log(`📊 Total questions to import: ${allQuestions.length}`);

    // Validate questions before import
    const validQuestions = [];
    const invalidQuestions = [];

    for (const q of allQuestions) {
      const isValid = q.subject === 'creativeArts' &&
                     q.examType === 'bece' &&
                     q.questionText &&
                     q.questionText.trim().length > 0 &&
                     q.questionNumber &&
                     q.year;

      if (isValid) {
        // Ensure proper data types
        const processedQuestion = {
          ...q,
          id: `creativeArts_${q.year}_${q.questionNumber}`,
          questionText: q.questionText.trim(),
          options: Array.isArray(q.options) ? q.options.map(opt => opt.trim()) : [],
          correctAnswer: q.correctAnswer || '',
          marks: 1,
          difficulty: 'medium',
          topics: ['Creative Arts and Design'],
          createdAt: new Date().toISOString(),
          createdBy: 'admin_import',
          isActive: true,
          sectionInstructions: q.sectionInstructions || null,
        };

        validQuestions.push(processedQuestion);
      } else {
        invalidQuestions.push(q);
      }
    }

    console.log(`✅ Valid questions: ${validQuestions.length}`);
    console.log(`❌ Invalid questions: ${invalidQuestions.length}`);

    if (invalidQuestions.length > 0) {
      console.log('Invalid questions:');
      invalidQuestions.forEach(q => {
        console.log(`  Q${q.questionNumber} (${q.year}): Missing required fields`);
      });
    }

    // Import questions in batches
    const batchSize = 10;
    let imported = 0;
    let skipped = 0;

    for (let i = 0; i < validQuestions.length; i += batchSize) {
      const batch = validQuestions.slice(i, i + batchSize);
      const batchPromises = batch.map(async (question) => {
        try {
          const docRef = db.collection('questions').doc(question.id);
          const doc = await docRef.get();

          if (doc.exists) {
            console.log(`⏭️  Skipping existing question: ${question.id}`);
            skipped++;
            return;
          }

          await docRef.set(question);
          console.log(`✅ Imported: ${question.id} - "${question.questionText.substring(0, 50)}..."`);
          imported++;
        } catch (error) {
          console.error(`❌ Failed to import ${question.id}:`, error.message);
        }
      });

      await Promise.all(batchPromises);

      // Small delay between batches to avoid rate limits
      if (i + batchSize < validQuestions.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }

    console.log('\n🎉 Import completed!');
    console.log(`📊 Total processed: ${validQuestions.length}`);
    console.log(`✅ Successfully imported: ${imported}`);
    console.log(`⏭️  Skipped (already exist): ${skipped}`);
    console.log(`❌ Failed: ${validQuestions.length - imported - skipped}`);

    // Verify the import by checking a few questions
    console.log('\n🔍 Verifying import...');
    const verificationQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .limit(5)
      .get();

    console.log(`📊 Found ${verificationQuery.docs.length} Creative Arts questions in database`);

    verificationQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  ✅ ${doc.id}: Q${data.questionNumber} (${data.year})`);
    });

  } catch (error) {
    console.error('❌ Import failed:', error);
  } finally {
    // Close the Firebase app
    await admin.app().delete();
  }
}

// Run the import
importCreativeArtsQuestions();