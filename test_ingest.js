const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

async function testIngestLocalPDFs() {
  try {
    console.log('Testing ingestLocalPDFs function call...');

    // Get the function
    const functions = require('firebase-functions');
    const { ingestLocalPDFs } = require('./functions/lib/ai/ingest');

    console.log('Function loaded:', typeof ingestLocalPDFs);

    // For testing, we'll call it directly (this would normally require auth context)
    // This is just to see if the function is accessible

  } catch (error) {
    console.error('Error:', error);
  }
}

testIngestLocalPDFs();