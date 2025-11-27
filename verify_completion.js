const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const subjectMappings = {
  'rme': 'religiousMoralEducation',
  'science': 'integratedScience',
  'social_studies': 'socialStudies',
  'english': 'english',
  'career_technology': 'careerTechnology',
  'creative_arts': 'creativeArts',
  'french': 'french',
  'ga': 'ga',
  'asante_twi': 'asanteTwi',
  'mathematics': 'mathematics'
};

async function verifyCompletion() {
  console.log('📊 BECE Subjects Completion Status:\n');

  let totalCollections = 0;
  let totalQuestions = 0;

  for (const [dirName, firestoreSubject] of Object.entries(subjectMappings)) {
    try {
      const indexPath = path.join('assets', dirName + '_questions_by_topic', 'index.json');
      const indexData = JSON.parse(fs.readFileSync(indexPath, 'utf8'));

      // Check Firestore collections based on subject
      let firestoreCollections = 0;
      let firestoreQuestions = 0;

      if (firestoreSubject === 'mathematics') {
        // Mathematics uses subjects/{subject}/topicCollections structure
        const collections = await db.collection('subjects').doc(firestoreSubject).collection('topicCollections').get();
        firestoreCollections = collections.size;
        collections.forEach(doc => {
          firestoreQuestions += doc.data().questionCount || 0;
        });
      } else {
        // Other subjects use questionCollections structure
        const collections = await db.collection('questionCollections')
          .where('subject', '==', firestoreSubject)
          .get();
        firestoreCollections = collections.size;
        collections.forEach(doc => {
          firestoreQuestions += doc.data().questionCount || 0;
        });
      }

      console.log(dirName.toUpperCase().replace('_', ' ') + ': ✅ ' + firestoreCollections + ' collections, ' + firestoreQuestions + ' questions');
      totalCollections += firestoreCollections;
      totalQuestions += firestoreQuestions;
    } catch (e) {
      console.log(dirName.toUpperCase().replace('_', ' ') + ': ❌ Error - ' + e.message);
    }
  }

  console.log('\n🎯 Grand Total: ' + totalCollections + ' collections across ' + Object.keys(subjectMappings).length + ' subjects, ' + totalQuestions + ' questions');
}

verifyCompletion().then(() => process.exit(0)).catch(err => {
  console.error('Verification failed:', err);
  process.exit(1);
});