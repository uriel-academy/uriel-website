const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Set environment variables from Firebase config
// Note: OPENAI_API_KEY should be set via environment variables, not hardcoded
// process.env.OPENAI_API_KEY = 'your-api-key-here';

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

async function callIngestLocalPDFs() {
  try {
    console.log('Calling ingestLocalPDFs Firebase function...');

    // Use Firebase Functions SDK to call the function
    const result = await functions().httpsCallable('ingestLocalPDFs')();
    console.log('Local PDF ingestion completed successfully');
    console.log('Result:', result);

  } catch (error) {
    console.error('Error calling ingestLocalPDFs:', error);
  }
}

// Run the function
callIngestLocalPDFs();