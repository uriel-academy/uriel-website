const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://uriel-academy-41fb0.firebaseio.com'
  });
}

const db = admin.firestore();

async function fixCreativeArtsQuestions() {
  try {
    console.log('🔧 Fixing Creative Arts and Design questions...\n');

    // Get all Creative Arts questions
    const snapshot = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .get();

    console.log(`📊 Found ${snapshot.docs.length} questions to process`);

    // Manual fixes for known problematic questions
    const fixes = {
      // Question 5 (2024) - options embedded in question text
      'creativeArts_2024_5': {
        questionText: 'Amadu, in an attempt to make his still-life drawing look real used parallel lines to depict the tones. This suggests that his shading is based on',
        options: ['criss-crossing', 'hatching', 'mass shading', 'stippling'],
        correctAnswer: 'hatching'
      },
      // Question 5 (2025) - completely malformed
      'creativeArts_2025_5': {
        questionText: 'What is the 3-dimensional form of a square?',
        options: ['cone', 'cube', 'cuboid', 'cylinder'],
        correctAnswer: 'cube'
      },
      // Question 13 (2024) - options embedded in question text
      'creativeArts_2024_13': {
        questionText: 'The Fante people of Ghana are noted for displaying variety of dances during occasions. Among such dances include',
        options: ['Adowa and Gome', 'Apatampa and Adowa', 'Bamaya and Bɔbɔɔbɔ', 'Gome and Bɔbɔɔbɔ'],
        correctAnswer: 'Apatampa and Adowa'
      },
      // Question 18 (2024) - options embedded in question text
      'creativeArts_2024_18': {
        questionText: 'Red, yellow, green and black are colours used in the flag of Ghana. The colour yellow symbolizes',
        options: ['agricultural prosperity', 'artistic heritage of the country', 'mineral wealth of the country', 'sun and its energy'],
        correctAnswer: 'mineral wealth of the country'
      },
      // Question 19 (2024) - options embedded in question text
      'creativeArts_2024_19': {
        questionText: 'The Atsiagbeko dance of the Ewe people of Ghana is said to be a',
        options: ['recreational dance', 'religious dance', 'spontaneous dance', 'war dance'],
        correctAnswer: 'war dance'
      },
      // Question 21 (2024) - options embedded in question text
      'creativeArts_2024_21': {
        questionText: 'Which of the following statements are true about Dance and Drama?',
        options: ['I and IV only', 'I and II only', 'I, II and III only', 'I, II and IV only'],
        correctAnswer: 'I and II only'
      },
      // Question 26 (2024) - options embedded in question text
      'creativeArts_2024_26': {
        questionText: 'Select the moral lesson from the lyricsMani mmere wo mpaboa no in the song "Kwaku Ananse" by Amerado',
        options: ['Do not be envious', 'Hard work always pay', 'Be determined', 'Be assertive'],
        correctAnswer: 'Do not be envious'
      },
      // Question 30 (2024) - options embedded in question text
      'creativeArts_2024_30': {
        questionText: 'In weaving a stole for graduation, Johny uses warp and weft yarns. For every new weft yarn he inserts into the shed, he beats to the',
        options: ['fell of the stole', 'middle of the stole', 'side of the stole', 'selvedge of the stole'],
        correctAnswer: 'fell of the stole'
      },
      // Question 31 (2024) - options embedded in question text
      'creativeArts_2024_31': {
        questionText: 'In designing a school bag, the role of working drawing is to',
        options: ['make a sketch model', 'evaluate the final product', 'identify problems', 'serve as a guide for production'],
        correctAnswer: 'serve as a guide for production'
      },
      // Question 36 (2024) - options embedded in question text
      'creativeArts_2024_36': {
        questionText: 'group called "Young Stars" of Kromkrom D/A JHS wants to create a skit to educate learners about the importance of proper handwashing.Identify the most effective way to convey their message to learners.',
        options: ['Use complex scientific terms', 'Use humor and related characters', 'Show graphic images of germs and diseases', 'Give a talk on importance of handwashing'],
        correctAnswer: 'Use humor and related characters'
      },
      // Question 37 (2024) - options embedded in question text
      'creativeArts_2024_37': {
        questionText: 'quarter note is placed on the 4th line of the staff. Its stem will be drawn',
        options: ['upward and on the right of the note', 'upward and on the left of the note', 'downward and on the left of the note', 'download and on the right of the note'],
        correctAnswer: 'upward and on the right of the note'
      },
      // Question 39 (2024) - options embedded in question text
      'creativeArts_2024_39': {
        questionText: 'An artist creates series of paintings that tell a story. The artist style of painting is associated with',
        options: ['abstract art', 'decorative art', 'narrative art', 'representational art'],
        correctAnswer: 'narrative art'
      },
      // Question 12 (2025) - options embedded in question text
      'creativeArts_2025_12': {
        questionText: 'In a composition, objects of the same kind and weight are said to have',
        options: ['balance', 'contrast', 'emphasis', 'unity'],
        correctAnswer: 'unity'
      },
      // Question 21 (2025) - options embedded in question text
      'creativeArts_2025_21': {
        questionText: 'Which of the following is the slowest tempo?',
        options: ['Largo', 'Andante', 'Allegro', 'Moderato'],
        correctAnswer: 'Largo'
      },
      // Question 29 (2025) - options embedded in question text
      'creativeArts_2025_29': {
        questionText: 'Which of the following is not a part of the stage?',
        options: ['Audience area', 'Backstage', 'Sound booth', 'Lighting'],
        correctAnswer: 'Audience area'
      }
    };

    // Fix premise questions - change sectionInstructions to proper instruction
    const premiseInstruction = 'Read the scenario below carefully and use it to answer the question below.';

    const premiseQuestions = [
      'creativeArts_2024_3', 'creativeArts_2024_4', 'creativeArts_2024_22',
      'creativeArts_2024_23', 'creativeArts_2024_24'
    ];

    let fixed = 0;
    let premiseFixed = 0;

    for (const doc of snapshot.docs) {
      const docId = doc.id;
      const data = doc.data();
      let updateData = {};

      // Apply manual fixes
      if (fixes[docId]) {
        updateData = { ...fixes[docId] };
        console.log(`🔧 Fixed question ${data.questionNumber} (${data.year}): ${fixes[docId].questionText.substring(0, 50)}...`);
        fixed++;
      }

      // Fix premise questions
      if (premiseQuestions.includes(docId)) {
        updateData.sectionInstructions = premiseInstruction;
        console.log(`📖 Fixed premise for question ${data.questionNumber} (${data.year})`);
        premiseFixed++;
      }

      // Apply updates
      if (Object.keys(updateData).length > 0) {
        await doc.ref.update(updateData);
      }
    }

    console.log(`\n✅ Fixed ${fixed} malformed questions`);
    console.log(`📋 Fixed ${premiseFixed} premise questions`);

    // Verification
    console.log('\n🔍 Verifying fixes...');
    const verificationQuery = await db.collection('questions')
      .where('subject', '==', 'creativeArts')
      .where('examType', '==', 'bece')
      .limit(10)
      .get();

    verificationQuery.docs.forEach(doc => {
      const data = doc.data();
      const hasOptions = Array.isArray(data.options) && data.options.length === 4;
      const hasAnswer = !!data.correctAnswer;
      console.log(`   Q${data.questionNumber} (${data.year}): ${hasOptions ? '✅' : '❌'} options, ${hasAnswer ? '✅' : '❌'} answer`);
    });

  } catch (error) {
    console.error('❌ Fix failed:', error);
  } finally {
    await admin.app().delete();
  }
}

// Run the fix
fixCreativeArtsQuestions();