const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixStudentNames() {
  try {
    console.log('🔍 Finding students with missing names...\n');
    
    const studentsSnapshot = await db.collection('users')
      .where('role', '==', 'student')
      .get();
    
    const studentsToFix = [];
    
    studentsSnapshot.forEach(doc => {
      const data = doc.data();
      const firstName = data.firstName;
      const lastName = data.lastName;
      const displayName = data.displayName;
      const email = data.email;
      
      // Check if names are missing or invalid
      if (!displayName || displayName === 'Student' || 
          !firstName || !lastName) {
        studentsToFix.push({
          id: doc.id,
          email: email,
          firstName: firstName,
          lastName: lastName,
          displayName: displayName
        });
      }
    });
    
    console.log(`Found ${studentsToFix.length} students with missing/incomplete names\n`);
    
    if (studentsToFix.length === 0) {
      console.log('✨ All students have proper names!');
      process.exit(0);
    }
    
    // Display students with issues
    studentsToFix.forEach((student, idx) => {
      console.log(`${idx + 1}. Email: ${student.email}`);
      console.log(`   First Name: ${student.firstName || 'MISSING'}`);
      console.log(`   Last Name: ${student.lastName || 'MISSING'}`);
      console.log(`   Display Name: ${student.displayName || 'MISSING'}`);
      console.log('');
    });
    
    // Fix each student with a default name based on email
    let fixedCount = 0;
    
    for (const student of studentsToFix) {
      try {
        let newFirstName = student.firstName;
        let newLastName = student.lastName;
        let newDisplayName = student.displayName;
        
        // If missing first/last name, derive from email
        if (!newFirstName || !newLastName) {
          const emailPrefix = student.email.split('@')[0];
          newFirstName = newFirstName || emailPrefix;
          newLastName = newLastName || 'Student';
        }
        
        // Set display name
        newDisplayName = `${newFirstName} ${newLastName}`;
        
        // Update user document
        await db.collection('users').doc(student.id).update({
          firstName: newFirstName,
          lastName: newLastName,
          displayName: newDisplayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Update studentSummaries if exists
        const summarySnapshot = await db.collection('studentSummaries')
          .where('studentId', '==', student.id)
          .limit(1)
          .get();
        
        if (!summarySnapshot.empty) {
          const summaryDoc = summarySnapshot.docs[0];
          await summaryDoc.ref.update({
            firstName: newFirstName,
            lastName: newLastName,
            displayName: newDisplayName,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        console.log(`✅ Fixed: ${newDisplayName} (${student.email})`);
        fixedCount++;
      } catch (error) {
        console.log(`❌ Failed to fix ${student.email}: ${error.message}`);
      }
    }
    
    console.log(`\n📊 Fixed ${fixedCount}/${studentsToFix.length} students`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixStudentNames();
