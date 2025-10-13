const admin = require('firebase-admin');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const bucket = admin.storage().bucket();

async function listStorageStructure() {
  try {
    console.log('\n=== Checking BECE RME Storage Structure ===\n');
    
    // Check main folder
    const [files] = await bucket.getFiles({ prefix: 'bece-rme' });
    
    console.log(`Total files found: ${files.length}\n`);
    
    // Group by path structure
    const structure = {};
    
    files.forEach(file => {
      const path = file.name;
      const parts = path.split('/');
      const folder = parts.slice(0, -1).join('/') || 'root';
      const filename = parts[parts.length - 1];
      
      if (!structure[folder]) {
        structure[folder] = [];
      }
      structure[folder].push({
        name: filename,
        size: file.metadata.size,
        created: file.metadata.timeCreated
      });
    });
    
    // Display structure
    for (const [folder, items] of Object.entries(structure)) {
      console.log(`📁 ${folder}/`);
      items.forEach(item => {
        console.log(`   📄 ${item.name} (${Math.round(item.size / 1024)} KB) - ${new Date(item.created).toISOString().split('T')[0]}`);
      });
      console.log('');
    }
    
    // Check specific paths
    console.log('\n=== Checking specific year folders ===\n');
    
    const years = ['1999', '2000', '2001', '2002', '2003', '2004', '2014', '2022'];
    
    for (const year of years) {
      const [yearFiles] = await bucket.getFiles({ prefix: `bece-rme questions/${year}` });
      if (yearFiles.length > 0) {
        console.log(`✓ Year ${year}: ${yearFiles.length} files found`);
        yearFiles.forEach(f => console.log(`  - ${f.name}`));
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

listStorageStructure();
