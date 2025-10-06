// Check if RME questions exist in Firestore
const https = require('https');

const data = JSON.stringify({
  data: {}
});

const options = {
  hostname: 'firestore.googleapis.com',
  port: 443,
  path: '/v1/projects/uriel-academy-41fb0/databases/(default)/documents/questions',
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
};

console.log('🔍 Checking for questions in Firestore...');

const req = https.request(options, (res) => {
  let responseData = '';
  
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('📤 Response Status:', res.statusCode);
    
    if (res.statusCode === 200) {
      try {
        const result = JSON.parse(responseData);
        const documents = result.documents || [];
        console.log(`📊 Found ${documents.length} total documents in questions collection`);
        
        // Check for RME questions
        const rmeQuestions = documents.filter(doc => {
          const fields = doc.fields || {};
          return fields.subject && fields.subject.stringValue === 'religiousMoralEducation';
        });
        
        console.log(`📚 Found ${rmeQuestions.length} RME questions`);
        
        if (rmeQuestions.length > 0) {
          console.log('✅ RME questions are in the database!');
          console.log('📋 First RME question:', rmeQuestions[0].fields.questionText?.stringValue || 'No question text');
        } else {
          console.log('❌ No RME questions found in database');
        }
        
      } catch (e) {
        console.log('📄 Error parsing response:', e.message);
      }
    } else {
      console.log('📄 Response:', responseData);
    }
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error.message);
});

req.end();