/**
 * Script to fetch Mathematics textbook sections from Firestore and convert to JSON
 * Run with: node fetch_mathematics_from_firestore.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'uriel-academy-41fb0'
});

const firestore = admin.firestore();

async function fetchMathematicsTextbooks() {
  console.log('\n📚 Fetching Mathematics textbook sections from Firestore...\n');

  try {
    // Fetch all mathematics sections (without orderBy to avoid index requirement)
    const snapshot = await firestore
      .collection('textbook_sections_markdown')
      .where('subject', '==', 'Mathematics')
      .get();

    console.log(`✅ Found ${snapshot.size} mathematics sections\n`);

    if (snapshot.empty) {
      console.log('⚠️  No mathematics sections found in Firestore');
      process.exit(0);
    }

    // Group sections by textbook (JHS 1, 2, 3)
    const textbooksData = {
      'mathematics_jhs_1': { chapters: [] },
      'mathematics_jhs_2': { chapters: [] },
      'mathematics_jhs_3': { chapters: [] }
    };

    const chaptersMap = {
      'mathematics_jhs_1': {},
      'mathematics_jhs_2': {},
      'mathematics_jhs_3': {}
    };

    // Process each section
    snapshot.forEach(doc => {
      const data = doc.data();
      const textbookId = data.textbookId;
      const chapterNum = data.chapterNumber;
      const sectionNum = data.sectionNumber;

      console.log(`📖 ${textbookId} - Chapter ${chapterNum}, Section ${sectionNum}: ${data.title}`);

      // Initialize chapter if not exists
      if (!chaptersMap[textbookId][chapterNum]) {
        chaptersMap[textbookId][chapterNum] = {
          id: `chapter_${chapterNum}`,
          chapterNumber: chapterNum,
          title: data.chapterTitle || `Chapter ${chapterNum}`,
          sections: []
        };
      }

      // Add section to chapter
      chaptersMap[textbookId][chapterNum].sections.push({
        id: `section_${chapterNum}_${sectionNum}`,
        sectionNumber: sectionNum,
        title: data.title,
        content: data.content,
        xpReward: 50,
        questions: data.questions || []
      });
    });

    // Convert chapters map to arrays
    Object.keys(chaptersMap).forEach(textbookId => {
      const chapters = Object.values(chaptersMap[textbookId]);
      chapters.sort((a, b) => a.chapterNumber - b.chapterNumber);
      
      // Sort sections within each chapter
      chapters.forEach(chapter => {
        chapter.sections.sort((a, b) => a.sectionNumber - b.sectionNumber);
      });
      
      textbooksData[textbookId].chapters = chapters;
    });

    // Save to JSON files
    const outputDir = path.join(__dirname, 'assets', 'textbooks');
    
    // Ensure directory exists
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    console.log('\n💾 Saving JSON files...\n');

    for (const [textbookId, data] of Object.entries(textbooksData)) {
      if (data.chapters.length > 0) {
        const filename = `${textbookId}.json`;
        const filepath = path.join(outputDir, filename);
        
        fs.writeFileSync(filepath, JSON.stringify(data, null, 2));
        
        const stats = fs.statSync(filepath);
        const sectionCount = data.chapters.reduce((sum, ch) => sum + ch.sections.length, 0);
        
        console.log(`✅ ${filename}`);
        console.log(`   📁 ${filepath}`);
        console.log(`   📊 ${data.chapters.length} chapters, ${sectionCount} sections`);
        console.log(`   💾 ${(stats.size / 1024).toFixed(2)} KB\n`);
      }
    }

    console.log('✨ Mathematics textbooks successfully converted to JSON!\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run the script
fetchMathematicsTextbooks();
