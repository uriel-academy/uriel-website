const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testGetSchoolStudents() {
  try {
    const studentsQuery = db.collection('users')
      .where('role', '==', 'student')
      .where('school', '==', 'Ave Maria')
      .orderBy('firstName')
      .limit(10);

    const studentsSnap = await studentsQuery.get();
    console.log('Found', studentsSnap.size, 'students');
    
    const studentIds = studentsSnap.docs.map(d => d.id);
    console.log('Student IDs:', studentIds);
    
    if (studentIds.length > 0) {
      const summariesSnap = await db.collection('studentSummaries')
        .where(admin.firestore.FieldPath.documentId(), 'in', studentIds)
        .get();
      
      console.log('\nStudent Summaries found:', summariesSnap.size);
      
      studentsSnap.docs.forEach(doc => {
        const userData = doc.data();
        console.log('\nStudent:', doc.id);
        console.log('  Name:', userData.displayName || (userData.firstName + ' ' + userData.lastName));
        console.log('  Email:', userData.email);
        console.log('  Class:', userData.class);
        console.log('  School:', userData.school);
      });
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
  process.exit(0);
}

testGetSchoolStudents();
