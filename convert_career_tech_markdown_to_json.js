/**
 * Script to convert Career Technology markdown files to JSON textbook format
 * Run with: node convert_career_tech_markdown_to_json.js
 */

const fs = require('fs');
const path = require('path');

const SECTIONS_DIR = path.join(__dirname, 'generated_sections');
const OUTPUT_DIR = path.join(__dirname, 'assets', 'textbooks');

// Parse filename to extract metadata
function parseFilename(filename) {
  // Format: career_tech_jhs1_ch1_sec1_topic.md
  const match = filename.match(/career_tech_jhs(\d+)_ch(\d+)_sec(\d+)_(.+)\.md/);
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
    1: 'Personal Development',
    2: 'Clothing and Textiles',
    3: 'Food and Nutrition',
    4: 'Home Management',
    5: 'Practical Skills'
  },
  2: {
    1: 'Career Development',
    2: 'Advanced Textiles',
    3: 'Culinary Skills',
    4: 'Home Economics',
    5: 'Technical Skills'
  },
  3: {
    1: 'Entrepreneurship',
    2: 'Fashion and Design',
    3: 'Hospitality Management',
    4: 'Resource Management',
    5: 'Applied Technology'
  }
};

async function convertMarkdownToJson() {
  console.log('\n📚 Converting Career Technology markdown files to JSON...\n');

  try {
    // Read all career tech markdown files
    const files = fs.readdirSync(SECTIONS_DIR)
      .filter(f => f.startsWith('career_tech_jhs') && f.endsWith('.md'));

    console.log(`✅ Found ${files.length} career technology section files\n`);

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
        id: `career_technology_jhs_${year}`,
        subject: 'Career Technology',
        year: `JHS ${year}`,
        title: `Uriel Academy Career Technology JHS ${year}`,
        description: `Complete Career Technology textbook for JHS ${year}`,
        coverImage: '',
        totalChapters: chaptersArray.length,
        totalSections: chaptersArray.reduce((sum, ch) => sum + ch.sections.length, 0),
        createdAt: new Date().toISOString(),
        chapters: chaptersArray
      };

      const filename = `career_technology_jhs_${year}.json`;
      const filepath = path.join(OUTPUT_DIR, filename);
      
      fs.writeFileSync(filepath, JSON.stringify(textbookData, null, 2));
      
      const stats = fs.statSync(filepath);
      const sectionCount = chaptersArray.reduce((sum, ch) => sum + ch.sections.length, 0);
      
      console.log(`✅ ${filename}`);
      console.log(`   📁 ${filepath}`);
      console.log(`   📊 ${chaptersArray.length} chapters, ${sectionCount} sections`);
      console.log(`   💾 ${(stats.size / 1024).toFixed(2)} KB\n`);
    }

    console.log('✨ Career Technology textbooks successfully converted to JSON!\n');
    console.log('📂 Files saved to: assets/textbooks/\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Run the script
convertMarkdownToJson();
