const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportTextbooksToJSON() {
  try {
    console.log('🔍 Finding English textbooks...');
    
    // Get all English textbooks
    const textbooksSnap = await db.collection('textbooks')
      .where('subject', '==', 'English')
      .get();
    
    if (textbooksSnap.empty) {
      console.log('❌ No English textbooks found');
      return;
    }
    
    console.log(`✅ Found ${textbooksSnap.docs.length} textbooks\n`);
    
    // Create output directory
    const outputDir = path.join(__dirname, 'assets', 'textbooks');
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
      console.log(`📁 Created directory: ${outputDir}\n`);
    }
    
    // Export each textbook
    for (const textbookDoc of textbooksSnap.docs) {
      const textbookData = textbookDoc.data();
      const textbookId = textbookDoc.id;
      
      console.log(`📖 Exporting: ${textbookData.title} (${textbookId})`);
      
      // Get all chapters
      const chaptersSnap = await textbookDoc.ref
        .collection('chapters')
        .orderBy('chapterNumber')
        .get();
      
      const chapters = [];
      
      for (const chapterDoc of chaptersSnap.docs) {
        const chapterData = chapterDoc.data();
        console.log(`  📑 Chapter ${chapterData.chapterNumber}: ${chapterData.title}`);
        
        // Get all sections for this chapter
        const sectionsSnap = await chapterDoc.ref
          .collection('sections')
          .orderBy('sectionNumber')
          .get();
        
        const sections = sectionsSnap.docs.map(sectionDoc => {
          const sectionData = sectionDoc.data();
          return {
            id: sectionDoc.id,
            sectionNumber: sectionData.sectionNumber,
            title: sectionData.title,
            content: sectionData.content,
            xpReward: sectionData.xpReward || 10,
            questions: sectionData.questions || []
          };
        });
        
        console.log(`    ✓ ${sections.length} sections`);
        
        chapters.push({
          id: chapterDoc.id,
          chapterNumber: chapterData.chapterNumber,
          title: chapterData.title,
          description: chapterData.description || '',
          xpReward: chapterData.xpReward || 50,
          sections: sections
        });
      }
      
      // Build complete textbook object
      const textbookJSON = {
        id: textbookId,
        subject: textbookData.subject,
        year: textbookData.year,
        title: textbookData.title,
        description: textbookData.description || '',
        coverImage: textbookData.coverImage || '',
        totalChapters: chapters.length,
        totalSections: chapters.reduce((sum, ch) => sum + ch.sections.length, 0),
        createdAt: textbookData.createdAt?.toDate().toISOString() || new Date().toISOString(),
        chapters: chapters
      };
      
      // Write to JSON file
      const filename = `${textbookId}.json`;
      const filepath = path.join(outputDir, filename);
      fs.writeFileSync(filepath, JSON.stringify(textbookJSON, null, 2), 'utf8');
      
      const fileSize = (fs.statSync(filepath).size / 1024).toFixed(2);
      console.log(`  ✅ Exported to: ${filename} (${fileSize} KB)`);
      console.log(`  📊 ${chapters.length} chapters, ${textbookJSON.totalSections} sections\n`);
    }
    
    console.log('🎉 Export complete!');
    console.log(`📂 Files saved to: ${outputDir}`);
    
  } catch (error) {
    console.error('❌ Export failed:', error);
  }
  
  process.exit();
}

exportTextbooksToJSON();
