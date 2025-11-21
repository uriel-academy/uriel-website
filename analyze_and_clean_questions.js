const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json'),
  });
}

const db = admin.firestore();

async function analyzeQuestions() {
  console.log('🔍 Analyzing questions in Firestore...\n');

  try {
    // Get all questions
    const questionsSnapshot = await db.collection('questions').get();

    console.log(`📊 Total questions: ${questionsSnapshot.size}\n`);

    // Group by subject and year
    const subjectStats = {};
    const yearStats = {};
    const subjectYearStats = {};

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || 'unknown';
      const year = data.year || 'unknown';

      // Count by subject
      subjectStats[subject] = (subjectStats[subject] || 0) + 1;

      // Count by year
      yearStats[year] = (yearStats[year] || 0) + 1;

      // Count by subject + year
      const key = `${subject}_${year}`;
      subjectYearStats[key] = (subjectYearStats[key] || 0) + 1;
    });

    console.log('📚 Questions by Subject:');
    Object.entries(subjectStats)
      .sort(([,a], [,b]) => b - a)
      .forEach(([subject, count]) => {
        console.log(`  ${subject}: ${count} questions`);
      });

    console.log('\n📅 Questions by Year:');
    Object.entries(yearStats)
      .sort(([,a], [,b]) => b - a)
      .forEach(([year, count]) => {
        console.log(`  ${year}: ${count} questions`);
      });

    console.log('\n🎯 Questions by Subject + Year:');
    Object.entries(subjectYearStats)
      .sort(([,a], [,b]) => b - a)
      .forEach(([key, count]) => {
        console.log(`  ${key}: ${count} questions`);
      });

    // Specifically check RME questions
    console.log('\n🔍 RME Questions Analysis:');
    const rmeQuestions = questionsSnapshot.docs.filter(doc => {
      const data = doc.data();
      return data.subject === 'religiousMoralEducation' || data.subject === 'rme';
    });

    console.log(`Total RME questions: ${rmeQuestions.length}`);

    const rmeByYear = {};
    rmeQuestions.forEach(doc => {
      const data = doc.data();
      const year = data.year || 'unknown';
      rmeByYear[year] = (rmeByYear[year] || 0) + 1;
    });

    console.log('RME by year:');
    Object.entries(rmeByYear)
      .sort(([,a], [,b]) => b - a)
      .forEach(([year, count]) => {
        console.log(`  ${year}: ${count} questions`);
      });

    // Check for mixed subjects in RME
    console.log('\n⚠️  Checking for mixed subjects in RME questions...');
    const mixedSubjects = {};
    rmeQuestions.forEach(doc => {
      const data = doc.data();
      const topics = data.topics || [];
      topics.forEach(topic => {
        if (topic !== 'Religious And Moral Education' && topic !== 'BECE' && !topic.match(/^\d{4}$/)) {
          mixedSubjects[topic] = (mixedSubjects[topic] || 0) + 1;
        }
      });
    });

    if (Object.keys(mixedSubjects).length > 0) {
      console.log('Found mixed topics in RME questions:');
      Object.entries(mixedSubjects)
        .sort(([,a], [,b]) => b - a)
        .forEach(([topic, count]) => {
          console.log(`  "${topic}": ${count} questions`);
        });
    } else {
      console.log('No mixed topics found in RME questions.');
    }

  } catch (error) {
    console.error('❌ Error analyzing questions:', error);
  }
}

async function deleteWrongSubjects() {
  console.log('\n🗑️  Deleting French, Creative Arts, and Career Technology questions...\n');

  try {
    const batch = db.batch();
    let deleteCount = 0;

    // Subjects to delete
    const subjectsToDelete = [
      'french',
      'creativeArts',
      'careerTechnology',
      'French',
      'Creative Arts',
      'Career Technology'
    ];

    // Also check for questions that have these in topics
    const wrongTopics = [
      'French',
      'Creative Arts',
      'Career Technology',
      'French Language',
      'Visual Arts',
      'Performing Arts',
      'Technical Drawing',
      'Pre-Technical Skills',
      'Home Economics'
    ];

    const questionsSnapshot = await db.collection('questions').get();

    questionsSnapshot.forEach(doc => {
      const data = doc.data();
      const subject = data.subject || '';
      const topics = data.topics || [];

      // Check if subject matches
      const subjectMatches = subjectsToDelete.some(s =>
        subject.toLowerCase().includes(s.toLowerCase())
      );

      // Check if topics contain wrong subjects
      const topicMatches = topics.some(topic =>
        wrongTopics.some(wrongTopic =>
          topic.toLowerCase().includes(wrongTopic.toLowerCase())
        )
      );

      if (subjectMatches || topicMatches) {
        batch.delete(doc.ref);
        deleteCount++;
        console.log(`🗑️  Deleting: ${doc.id} (${subject}) - Topics: ${topics.join(', ')}`);
      }
    });

    if (deleteCount > 0) {
      await batch.commit();
      console.log(`\n✅ Successfully deleted ${deleteCount} questions`);
    } else {
      console.log('\nℹ️  No questions found to delete');
    }

  } catch (error) {
    console.error('❌ Error deleting questions:', error);
  }
}

// Run the analysis
analyzeQuestions().then(() => {
  // Ask user if they want to proceed with deletion
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.question('\n❓ Do you want to delete French, Creative Arts, and Career Technology questions? (yes/no): ', (answer) => {
    if (answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y') {
      deleteWrongSubjects().then(() => {
        console.log('\n🔄 Re-running analysis after deletion...');
        return analyzeQuestions();
      }).then(() => {
        console.log('\n✅ Cleanup complete!');
        process.exit(0);
      });
    } else {
      console.log('ℹ️  Deletion cancelled.');
      process.exit(0);
    }
    rl.close();
  });
}).catch(error => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});