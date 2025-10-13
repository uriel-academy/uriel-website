const { initializeApp } = require('firebase/app');
const { getFunctions, httpsCallable, connectFunctionsEmulator } = require('firebase/functions');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const firebaseConfig = {
  apiKey: "AIzaSyA2RQqP9_6MFY5_r4T8hKgLPF-9vZj8k7Q",
  authDomain: "uriel-academy-41fb0.firebaseapp.com",
  projectId: "uriel-academy-41fb0",
  storageBucket: "uriel-academy-41fb0.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdef1234567890abcdef"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const functions = getFunctions(app, 'us-central1');
const auth = getAuth(app);

async function testImportRME() {
  try {
    console.log('Authenticating...');
    
    // Sign in with admin email (you'll need to provide the password)
    const email = 'studywithuriel@gmail.com';
    const password = 'your_password_here'; // Replace with actual password
    
    await signInWithEmailAndPassword(auth, email, password);
    console.log('Authentication successful');
    
    // Call the import function
    console.log('Calling importRMEQuestions function...');
    const importRMEQuestions = httpsCallable(functions, 'importRMEQuestions');
    const result = await importRMEQuestions();
    
    console.log('Import result:', result.data);
    
    if (result.data.success) {
      console.log('✅ Import successful!');
      console.log(`📝 ${result.data.questionsImported} questions imported`);
      console.log(`💬 ${result.data.message}`);
    } else {
      console.log('❌ Import failed:', result.data.message);
    }
    
  } catch (error) {
    console.error('Error:', error);
    if (error.code === 'functions/unauthenticated') {
      console.log('❌ Authentication required. Please sign in as admin.');
    } else if (error.code === 'functions/permission-denied') {
      console.log('❌ Permission denied. Admin access required.');
    } else {
      console.log('❌ Unexpected error:', error.message);
    }
  }
}

// Run the test
testImportRME().then(() => {
  console.log('Test completed');
  process.exit(0);
}).catch((error) => {
  console.error('Test failed:', error);
  process.exit(1);
});