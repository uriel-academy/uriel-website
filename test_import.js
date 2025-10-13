const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID only (uses Application Default Credentials)
admin.initializeApp({
  projectId: 'uriel-academy-41fb0'
});

const db = admin.firestore();

async function testConnection() {
  try {
    console.log('Testing Firestore connection...');
    
    // Try to write a test document
    const testDoc = {
      test: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      message: 'RME import test'
    };
    
    await db.collection('test').doc('connection').set(testDoc);
    console.log('✅ Firestore connection successful!');
    
    // Now import one RME question as test
    const rmeQuestion = {
      id: 'rme_1999_q1_test',
      questionText: "According to Christian teaching, God created man and woman on the",
      type: 'multipleChoice',
      subject: 'religiousMoralEducation',
      examType: 'bece',
      year: '1999',
      section: 'A',
      questionNumber: 1,
      options: ["A. 1st day", "B. 2nd day", "C. 3rd day", "D. 5th day", "E. 6th day"],
      correctAnswer: "E",
      explanation: "This is a test question from the 1999 BECE RME exam.",
      marks: 1,
      difficulty: 'medium',
      topics: ['Religious And Moral Education', 'BECE', '1999'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: 'system_import',
      isActive: true,
      metadata: {
        source: 'BECE 1999',
        importDate: admin.firestore.FieldValue.serverTimestamp(),
        verified: true
      }
    };
    
    await db.collection('questions').doc(rmeQuestion.id).set(rmeQuestion);
    console.log('✅ Successfully imported test RME question!');
    
    console.log('🎉 Import test completed successfully!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    process.exit(0);
  }
}

// Set the Google Application Credentials environment variable
process.env.GOOGLE_APPLICATION_CREDENTIALS = './android/app/google-services.json';

testConnection();