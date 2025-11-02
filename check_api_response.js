const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkAPIResponse() {
  try {
    const getClassAggregates = admin.functions().httpsCallable('getClassAggregates');
    
    const result = await getClassAggregates({
      teacherId: '2Uinubzgjhd9AWQQPfKOyK5D5a62'
    });
    
    console.log('\n=== API Response Structure ===');
    console.log('Total Students:', result.data.students.length);
    
    result.data.students.forEach((student, idx) => {
      console.log(`\n${idx + 1}. ${student.displayName}`);
      console.log('   Fields available:');
      Object.keys(student).forEach(key => {
        if (key !== 'raw') {
          console.log(`   - ${key}: ${student[key]}`);
        }
      });
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkAPIResponse();
