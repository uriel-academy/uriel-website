const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

async function run() {
  const saPath = path.resolve(__dirname, '..', '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  const sa = require(saPath);
  if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
  const db = admin.firestore();

  const assetsDir = path.join(__dirname, '..', '..', 'assets', 'bece Career Technology');
  if (!fs.existsSync(assetsDir)) {
    console.error('Assets folder not found:', assetsDir);
    process.exit(1);
  }

  const docxFiles = fs.readdirSync(assetsDir).filter(f => f.toLowerCase().endsWith('.docx'));
  if (docxFiles.length === 0) {
    console.log('No docx files found in', assetsDir);
    return;
  }

  console.log('Found', docxFiles.length, 'docx files. Will update matching questions subject to career_technology where metadata.sourceFile matches the filename.');

  for (const filename of docxFiles) {
    try {
      const snapshot = await db.collection('questions').where('metadata.sourceFile', '==', filename).get();
      if (snapshot.empty) {
        console.log('  No questions found for', filename);
        continue;
      }
      console.log('  Updating', snapshot.size, 'docs for', filename);
      const batch = db.batch();
      snapshot.docs.forEach(doc => {
        const ref = doc.ref;
        batch.update(ref, { subject: 'career_technology', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      });
      await batch.commit();
      console.log('  Updated docs for', filename);
    } catch (e) {
      console.error('Failed to update for', filename, e && e.message ? e.message : e);
    }
  }

  console.log('Done. Consider running the verification script to confirm subjects.');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
