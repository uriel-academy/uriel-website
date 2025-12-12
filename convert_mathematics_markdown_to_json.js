/**
 * Script to convert Mathematics markdown files to JSON textbook format
 * Run with: node convert_mathematics_markdown_to_json.js
 */

const fs = require('fs');
const path = require('path');

const SECTIONS_DIR = path.join(__dirname, 'generated_sections');
const OUTPUT_DIR = path.join(__dirname, 'assets', 'textbooks');

// Parse filename to extract metadata
function parseFilename(filename) {
  // Format: mathematics_jhs1_ch1_sec1_topic.md
  const match = filename.match(/mathematics_jhs(\d+)_ch(\d+)_sec(\d+)_(.+)\.md/);
  if (!match) return null;
  
  return {
    year: parseInt(match[1]),
    chapter: parseInt(match[2]),
    section: parseInt(match[3]),
    topic: match[4].replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
  };
}

// Chapter titles for each JHS level
const CHAPTER_TITLES = {
  1: {
    1: 'Numbers and Numeration',
    2: 'Basic Algebra',
    3: 'Geometry Basics',
    4: 'Measurement',
    5: 'Data Handling'
  },
  2: {
    1: 'Advanced Numbers',
    2: 'Algebraic Expressions',
    3: 'Geometry and Shapes',
    4: 'Trigonometry Basics',
    5: 'Statistics'
  },
  3: {
    1: 'Number Systems',
    2: 'Advanced Algebra',
    3: 'Coordinate Geometry',
    4: 'Trigonometry',
    5: 'Probability and Statistics'
  }
};

async function convertMarkdownToJson() {
  console.log('\n📚 Converting Mathematics markdown files to JSON...\n');

  try {
    // Read all mathematics markdown files
    const files = fs.readdirSync(SECTIONS_DIR)
      .filter(f => f.startsWith('mathematics_jhs') && f.endsWith('.md'));

    console.log(`✅ Found ${files.length} mathematics section files\n`);

    // Group by JHS year
    const textbooks = {
      1: { chapters: {} },
      2: { chapters: {} },
      3: { chapters: {} }
    };

    // Process each file
    for (const filename of files) {
      const metadata = parseFilename(filename);
      if (!metadata) {
        console.log(`⚠️  Skipping invalid filename: ${filename}`);
        continue;
      }

      const filepath = path.join(SECTIONS_DIR, filename);
      const content = fs.readFileSync(filepath, 'utf-8');

      const { year, chapter, section, topic } = metadata;

      // Initialize chapter if not exists
      if (!textbooks[year].chapters[chapter]) {
        textbooks[year].chapters[chapter] = {
          id: `chapter_${chapter}`,
          chapterNumber: chapter,
          title: CHAPTER_TITLES[year][chapter] || `Chapter ${chapter}`,
          sections: []
        };
      }

      // Add section
      textbooks[year].chapters[chapter].sections.push({
        id: `section_${chapter}_${section}`,
        sectionNumber: section,
        title: topic,
        content: content,
        xpReward: 50,
        questions: []
      });

      console.log(`📖 JHS ${year} - Ch ${chapter}, Sec ${section}: ${topic}`);
    }

    // Ensure output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    console.log('\n💾 Saving JSON files...\n');

    // Save each textbook
    for (const [year, data] of Object.entries(textbooks)) {
      // Convert chapters object to sorted array
      const chaptersArray = Object.values(data.chapters);
      chaptersArray.sort((a, b) => a.chapterNumber - b.chapterNumber);
      
      // Sort sections within each chapter
      chaptersArray.forEach(chapter => {
        chapter.sections.sort((a, b) => a.sectionNumber - b.sectionNumber);
      });

      const textbookData = {
        id: `mathematics_jhs_${year}`,
        subject: 'Mathematics',
        year: `JHS ${year}`,
        title: `Uriel Academy Mathematics JHS ${year}`,
        description: `Complete Mathematics textbook for JHS ${year}`,
        coverImage: '',
        totalChapters: chaptersArray.length,
        totalSections: chaptersArray.reduce((sum, ch) => sum + ch.sections.length, 0),
        createdAt: new Date().toISOString(),
        chapters: chaptersArray
      };

      const filename = `mathematics_jhs_${year}.json`;
      const filepath = path.join(OUTPUT_DIR, filename);
      
      fs.writeFileSync(filepath, JSON.stringify(textbookData, null, 2));
      
      const stats = fs.statSync(filepath);
      const sectionCount = chaptersArray.reduce((sum, ch) => sum + ch.sections.length, 0);
      
      console.log(`✅ ${filename}`);
      console.log(`   📁 ${filepath}`);
      console.log(`   📊 ${chaptersArray.length} chapters, ${sectionCount} sections`);
      console.log(`   💾 ${(stats.size / 1024).toFixed(2)} KB\n`);
    }

    console.log('✨ Mathematics textbooks successfully converted to JSON!\n');
    console.log('📂 Files saved to: assets/textbooks/\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Run the script
convertMarkdownToJson();
