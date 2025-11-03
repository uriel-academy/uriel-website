const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkStudentFields() {
  try {
    const studentsSnap = await db.collection('users')
      .where('role', '==', 'student')
      .limit(2)
      .get();
    
    console.log('Found', studentsSnap.size, 'students');
    studentsSnap.forEach(doc => {
      const data = doc.data();
      console.log('\nStudent:', doc.id);
      console.log('Has school field:', 'school' in data, '- Value:', data.school);
      console.log('Has tenant field:', 'tenant' in data, '- Value:', JSON.stringify(data.tenant));
      console.log('firstName:', data.firstName);
    });
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit(0);
}

checkStudentFields();
