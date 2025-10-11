const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function verifyStorybooksImport() {
  console.log('🔍 Verifying Storybooks Import...\n');
  
  try {
    // Get all storybooks (wait for index to build)
    console.log('⏳ Waiting for Firestore index to build (this may take a few minutes)...\n');
    
    const snapshot = await db.collection('storybooks').get();
    
    console.log(`📚 Total Storybooks: ${snapshot.size}`);
    console.log('='.repeat(80));
    
    // Get statistics
    const stats = {
      totalBooks: snapshot.size,
      totalSize: 0,
      formats: {},
      authors: new Set(),
      categories: new Set(),
      newReleases: 0,
    };
    
    // Sample books
    console.log('\n📖 Sample Books (First 10):');
    console.log('-'.repeat(80));
    
    snapshot.docs.slice(0, 10).forEach((doc, index) => {
      const book = doc.data();
      console.log(`${index + 1}. "${book.title}" by ${book.author}`);
      console.log(`   Format: ${book.format.toUpperCase()} | Size: ${(book.fileSize / 1024 / 1024).toFixed(2)} MB`);
      console.log(`   Path: ${book.assetPath}`);
      console.log(`   Read Count: ${book.readCount} | Free: ${book.isFree ? 'Yes' : 'No'}`);
      console.log();
    });
    
    // Calculate statistics
    snapshot.docs.forEach(doc => {
      const book = doc.data();
      stats.totalSize += book.fileSize;
      stats.formats[book.format] = (stats.formats[book.format] || 0) + 1;
      stats.authors.add(book.author);
      stats.categories.add(book.category);
      
      // Check if new (within last 30 days)
      if (book.createdAt) {
        const createdDate = book.createdAt.toDate();
        const daysSinceCreation = Math.floor((Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24));
        if (daysSinceCreation <= 30) {
          stats.newReleases++;
        }
      }
    });
    
    // Display statistics
    console.log('\n📊 Statistics:');
    console.log('='.repeat(80));
    console.log(`Total Books: ${stats.totalBooks}`);
    console.log(`Total Size: ${(stats.totalSize / 1024 / 1024).toFixed(2)} MB`);
    console.log(`Formats: ${Object.entries(stats.formats).map(([k, v]) => `${k.toUpperCase()} (${v})`).join(', ')}`);
    console.log(`Unique Authors: ${stats.authors.size}`);
    console.log(`Categories: ${Array.from(stats.categories).join(', ')}`);
    console.log(`New Releases (Last 30 days): ${stats.newReleases}`);
    
    // Display top authors
    const authorCounts = {};
    snapshot.docs.forEach(doc => {
      const author = doc.data().author;
      authorCounts[author] = (authorCounts[author] || 0) + 1;
    });
    
    const topAuthors = Object.entries(authorCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10);
    
    console.log('\n👨‍🎨 Top 10 Authors:');
    console.log('-'.repeat(80));
    topAuthors.forEach(([author, count], index) => {
      console.log(`${index + 1}. ${author} (${count} book${count > 1 ? 's' : ''})`);
    });
    
    // Check for issues
    console.log('\n🔍 Data Quality Check:');
    console.log('-'.repeat(80));
    
    let issuesFound = 0;
    snapshot.docs.forEach(doc => {
      const book = doc.data();
      
      if (!book.title || book.title === 'Unknown Title') {
        console.log(`⚠️  Missing/Unknown title: ${doc.id}`);
        issuesFound++;
      }
      
      if (!book.author || book.author === 'Unknown Author') {
        console.log(`⚠️  Missing/Unknown author: ${doc.id} - "${book.title}"`);
        issuesFound++;
      }
      
      if (!book.assetPath || !book.assetPath.startsWith('assets/storybooks/')) {
        console.log(`⚠️  Invalid asset path: ${doc.id} - ${book.assetPath}`);
        issuesFound++;
      }
      
      if (book.fileSize <= 0) {
        console.log(`⚠️  Invalid file size: ${doc.id} - ${book.fileSize}`);
        issuesFound++;
      }
    });
    
    if (issuesFound === 0) {
      console.log('✅ No data quality issues found!');
    } else {
      console.log(`⚠️  Found ${issuesFound} potential issues.`);
    }
    
    console.log('\n' + '='.repeat(80));
    console.log('✨ Verification Complete!');
    
  } catch (error) {
    console.error('❌ Error verifying storybooks:', error);
  } finally {
    process.exit(0);
  }
}

// Run verification
verifyStorybooksImport();
