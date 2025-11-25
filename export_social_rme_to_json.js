/**
 * Export Social Studies and RME Textbooks from Firestore to JSON
 * Similar to English textbooks format
 */

require('dotenv').config();
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function exportTextbookToJson(textbookId, subject) {
  console.log(`\n📖 Exporting ${textbookId}...`);
  
  try {
    // Get textbook metadata
    const textbookDoc = await db.collection('textbooks').doc(textbookId).get();
    
    if (!textbookDoc.exists) {
      console.log(`❌ Textbook ${textbookId} not found`);
      return null;
    }
    
    const textbookData = textbookDoc.data();
    
    // Get all chapters
    const chaptersSnapshot = await db.collection('textbooks')
      .doc(textbookId)
      .collection('chapters')
      .orderBy('chapterNumber')
      .get();
    
    const chapters = [];
    
    for (const chapterDoc of chaptersSnapshot.docs) {
      const chapterData = chapterDoc.data();
      
      // Get all sections for this chapter
      const sectionsSnapshot = await db.collection('textbooks')
        .doc(textbookId)
        .collection('chapters')
        .doc(chapterDoc.id)
        .collection('sections')
        .orderBy('sectionNumber')
        .get();
      
      const sections = [];
      
      for (const sectionDoc of sectionsSnapshot.docs) {
        const sectionData = sectionDoc.data();
        
        // Get questions from section data (they're stored as an array in the section)
        let questions = [];
        if (sectionData.questions && Array.isArray(sectionData.questions)) {
          questions = sectionData.questions.map(q => ({
            id: q.id || `q_${questions.length + 1}`,
            questionNumber: q.questionNumber || questions.length + 1,
            question: q.questionText || q.question || '',
            options: q.options || {},
            correctAnswer: q.correctAnswer || '',
            explanation: q.explanation || '',
            difficulty: q.difficulty || 'medium',
            xpReward: q.xpValue || q.xpReward || 20,
          }));
        }
        
        sections.push({
          id: sectionDoc.id,
          sectionNumber: sectionData.sectionNumber,
          title: sectionData.title,
          content: sectionData.content,
          learningObjectives: sectionData.learningObjectives || [],
          keyTerms: sectionData.keyTerms || [],
          imageUrl: sectionData.imageUrl || null,
          xpReward: sectionData.xpReward || 50,
          questions: questions,
        });
      }
      
      chapters.push({
        id: chapterDoc.id,
        chapterNumber: chapterData.chapterNumber,
        title: chapterData.title,
        description: chapterData.description || '',
        sections: sections,
      });
      
      console.log(`   ✓ Chapter ${chapterData.chapterNumber}: ${sections.length} sections`);
    }
    
    // Build final JSON structure
    const textbookJson = {
      id: textbookId,
      title: textbookData.title,
      subject: textbookData.subject,
      year: textbookData.year,
      description: textbookData.description || '',
      coverImage: getCoverImagePath(subject, textbookData.year),
      totalChapters: chapters.length,
      totalSections: chapters.reduce((sum, ch) => sum + ch.sections.length, 0),
      totalQuestions: chapters.reduce((sum, ch) => 
        sum + ch.sections.reduce((s, sec) => s + sec.questions.length, 0), 0),
      generatedBy: textbookData.generatedBy || 'OpenAI GPT-4o',
      features: textbookData.features || [
        'Comprehensive content aligned with Ghana Education Service curriculum',
        'Interactive questions with immediate feedback',
        'Rich markdown formatting with tables and lists',
        'XP rewards for reading and answering questions'
      ],
      chapters: chapters,
    };
    
    return textbookJson;
    
  } catch (error) {
    console.error(`❌ Error exporting ${textbookId}:`, error);
    return null;
  }
}

function getCoverImagePath(subject, year) {
  const yearNum = year.replace('JHS ', '');
  if (subject === 'Social Studies') {
    return `assets/social-studies_jhs${yearNum}.png`;
  } else if (subject.includes('RME') || subject.includes('Religious')) {
    return `assets/rme_jhs${yearNum}.png`;
  }
  return '';
}

async function exportAllTextbooks() {
  console.log('📚 Exporting Social Studies and RME Textbooks to JSON...\n');
  
  const assetsDir = path.join(__dirname, 'assets', 'textbooks');
  
  // Create assets/textbooks directory if it doesn't exist
  if (!fs.existsSync(assetsDir)) {
    fs.mkdirSync(assetsDir, { recursive: true });
    console.log('✓ Created assets/textbooks directory');
  }
  
  try {
    // Export Social Studies textbooks
    console.log('\n=== SOCIAL STUDIES TEXTBOOKS ===');
    const socialStudiesIds = [
      'social_studies_jhs_1',
      'social_studies_jhs_2',
      'social_studies_jhs_3'
    ];
    
    for (const textbookId of socialStudiesIds) {
      const textbookJson = await exportTextbookToJson(textbookId, 'Social Studies');
      
      if (textbookJson) {
        const filename = `${textbookId}.json`;
        const filepath = path.join(assetsDir, filename);
        fs.writeFileSync(filepath, JSON.stringify(textbookJson, null, 2));
        console.log(`   ✅ Saved to ${filename}`);
        console.log(`   📊 ${textbookJson.totalChapters} chapters, ${textbookJson.totalSections} sections, ${textbookJson.totalQuestions} questions`);
      }
    }
    
    // Export RME textbooks (only those that have content)
    console.log('\n=== RME TEXTBOOKS ===');
    const rmeIds = [
      'religious_and_moral_education_jhs_1',
      'religious_and_moral_education_jhs_2',
      'religious_and_moral_education_jhs_3'
    ];
    
    for (const textbookId of rmeIds) {
      const textbookJson = await exportTextbookToJson(textbookId, 'RME');
      
      if (textbookJson && textbookJson.totalChapters > 0) {
        const filename = `${textbookId}.json`;
        const filepath = path.join(assetsDir, filename);
        fs.writeFileSync(filepath, JSON.stringify(textbookJson, null, 2));
        console.log(`   ✅ Saved to ${filename}`);
        console.log(`   📊 ${textbookJson.totalChapters} chapters, ${textbookJson.totalSections} sections, ${textbookJson.totalQuestions} questions`);
      } else {
        console.log(`   ⚠️ ${textbookId} has no content, skipping`);
      }
    }
    
    console.log('\n✅ Export complete!');
    console.log(`\n📁 JSON files saved to: ${assetsDir}`);
    
  } catch (error) {
    console.error('❌ Error during export:', error);
  }
  
  process.exit(0);
}

exportAllTextbooks();
