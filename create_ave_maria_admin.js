const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const email = 'wilfredsamaddo@gmail.com';
const password = 'Qwertyz1!';
const schoolName = 'Ave Maria School';
const schoolCode = 'PRGA03AM71';

async function createSchoolAdmin() {
  try {
    // 1. Check if school exists with this code
    console.log(`Looking for school with code: ${schoolCode}`);
    const schoolsSnapshot = await admin.firestore().collection('schools')
      .where('schoolCode', '==', schoolCode)
      .limit(1)
      .get();
    
    let schoolId;
    if (!schoolsSnapshot.empty) {
      schoolId = schoolsSnapshot.docs[0].id;
      console.log(`✓ Found existing school: ${schoolId}`);
    } else {
      // Create new school if doesn't exist
      console.log('Creating new school document...');
      const schoolRef = admin.firestore().collection('schools').doc();
      await schoolRef.set({
        name: schoolName,
        schoolCode: schoolCode,
        address: '',
        contactEmail: email,
        contactPhone: '',
        region: 'Greater Accra',
        district: '',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        subscriptionPlan: 'basic',
        studentLimit: 100,
        teacherLimit: 10
      });
      schoolId = schoolRef.id;
      console.log(`✓ Created school: ${schoolId}`);
    }
    
    // 2. Create user in Firebase Auth
    console.log('Creating user in Firebase Auth...');
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      emailVerified: true,
      displayName: 'Ave Maria Admin'
    });
    console.log(`✓ Created Auth user: ${userRecord.uid}`);
    
    // 3. Create user document in Firestore with school admin role
    console.log('Creating user document in Firestore...');
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      firstName: 'Ave Maria',
      lastName: 'Admin',
      role: 'school_admin',
      class: 'JHS FORM 3',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      tenant: {
        schoolId: schoolId,
        schoolName: schoolName,
        schoolCode: schoolCode,
        role: 'school_admin'
      },
      stats: {
        totalXP: 0,
        questionsAnswered: 0,
        correctAnswers: 0,
        currentStreak: 0,
        longestStreak: 0
      }
    });
    console.log(`✓ Created user document with school_admin role`);
    
    // 4. Set custom claims for authorization
    console.log('Setting custom claims...');
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: 'school_admin',
      schoolId: schoolId
    });
    console.log(`✓ Set custom claims`);
    
    console.log('\n✅ Ave Maria School Admin created successfully!');
    console.log(`📧 Email: ${email}`);
    console.log(`🔑 Password: ${password}`);
    console.log(`🏫 School: ${schoolName}`);
    console.log(`🔢 School Code: ${schoolCode}`);
    console.log(`🆔 School ID: ${schoolId}`);
    console.log(`👤 User ID: ${userRecord.uid}`);
    
  } catch (error) {
    console.error('❌ Error creating school admin:', error);
  }
  
  await admin.app().delete();
}

createSchoolAdmin();
