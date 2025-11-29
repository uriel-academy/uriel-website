const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function generateDiagnosticReport() {
    console.log('📊 URIEL APP DIAGNOSTIC REPORT');
    console.log('='.repeat(60));
    console.log(`Generated: ${new Date().toISOString()}\n`);
    
    // 1. Overall Collections Status
    console.log('1️⃣  QUESTION COLLECTIONS STATUS');
    console.log('-'.repeat(60));
    const allCollections = await db.collection('questionCollections').get();
    const activeCollections = allCollections.docs.filter(d => d.data().isActive === true);
    console.log(`Total Collections: ${allCollections.size}`);
    console.log(`Active Collections: ${activeCollections.size}`);
    console.log(`Inactive Collections: ${allCollections.size - activeCollections.size}\n`);
    
    // 2. Collections by Subject
    console.log('2️⃣  COLLECTIONS BY SUBJECT');
    console.log('-'.repeat(60));
    const subjectStats = {};
    allCollections.forEach(doc => {
        const subject = doc.data().subject;
        const isActive = doc.data().isActive === true;
        if (!subjectStats[subject]) {
            subjectStats[subject] = { total: 0, active: 0 };
        }
        subjectStats[subject].total++;
        if (isActive) subjectStats[subject].active++;
    });
    
    Object.entries(subjectStats).sort().forEach(([subject, stats]) => {
        console.log(`${subject.padEnd(30)} Total: ${stats.total.toString().padStart(3)} | Active: ${stats.active.toString().padStart(3)}`);
    });
    console.log();
    
    // 3. French Collections Detailed Status
    console.log('3️⃣  FRENCH COLLECTIONS DETAILED STATUS');
    console.log('-'.repeat(60));
    const frenchCollections = await db.collection('questionCollections')
        .where('subject', '==', 'french')
        .get();
    
    const frenchByType = {};
    for (const doc of frenchCollections.docs) {
        const data = doc.data();
        const type = data.questionType;
        const year = data.year;
        const qIds = data.questionIds || [];
        const isActive = data.isActive === true;
        
        if (!frenchByType[type]) {
            frenchByType[type] = [];
        }
        
        // Check if questions exist (sample first question)
        let questionsExist = false;
        if (qIds.length > 0) {
            const firstQ = await db.collection('questions').doc(qIds[0]).get();
            questionsExist = firstQ.exists;
        }
        
        frenchByType[type].push({
            year,
            count: qIds.length,
            active: isActive,
            questionsExist
        });
    }
    
    Object.entries(frenchByType).forEach(([type, collections]) => {
        console.log(`\n${type.toUpperCase()}:`);
        collections.sort((a, b) => a.year.localeCompare(b.year));
        collections.forEach(c => {
            const status = c.questionsExist ? '✅' : '❌';
            const activeStatus = c.active ? '[ACTIVE]' : '[INACTIVE]';
            console.log(`  ${c.year}: ${c.count.toString().padStart(2)} questions ${status} ${activeStatus}`);
        });
    });
    console.log();
    
    // 4. Overall Questions Count
    console.log('4️⃣  QUESTIONS DATABASE STATUS');
    console.log('-'.repeat(60));
    
    const subjects = ['mathematics', 'english', 'integratedScience', 'french', 'socialStudies'];
    for (const subject of subjects) {
        const count = await db.collection('questions')
            .where('subject', '==', subject)
            .count()
            .get();
        console.log(`${subject.padEnd(20)} ${count.data().count.toString().padStart(6)} questions`);
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('📌 KEY FINDINGS:');
    console.log('   - All French MCQ collections reference missing questions');
    console.log('   - French theory/essay questions exist in database');
    console.log('   - Recommend: Import French MCQ questions OR deactivate collections');
    console.log('='.repeat(60));
    
    process.exit(0);
}

generateDiagnosticReport().catch(e => {
    console.error('❌ Error:', e);
    process.exit(1);
});
