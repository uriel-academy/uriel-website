const fs = require('fs');

/**
 * Add underline markers to English questions
 * Format: <u>word</u> or [u]word[/u] to mark words that should be underlined
 * 
 * For Section B (synonyms): Usually the key vocabulary word (often more sophisticated)
 * For Section C (idioms): The idiomatic phrase
 * For Section D (antonyms): The word to find opposite for
 */

function addUnderlineMarkers(filePath) {
  console.log(`\n📖 Reading ${filePath}...`);
  
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  
  let updatedCount = 0;
  let skippedCount = 0;
  
  data.questions.forEach(question => {
    const section = question.section;
    const questionText = question.questionText;
    
    // Skip if already has underline markers
    if (questionText.includes('<u>') || questionText.includes('[u]')) {
      skippedCount++;
      return;
    }
    
    // For Section B: Find the key word to underline (usually a less common word)
    if (section === 'B') {
      // Common patterns: The meaningful word is often a sophisticated vocabulary word
      // Examples: "Her ambition is..." -> ambition
      //           "The benefit of..." -> benefit
      //           "too scared to..." -> scared
      
      const markedText = autoUnderlineSectionB(questionText);
      if (markedText !== questionText) {
        question.questionText = markedText;
        updatedCount++;
      }
    }
    
    // For Section C: Usually has phrases like "shed crocodile tears", "hair stood on end"
    else if (section === 'C') {
      const markedText = autoUnderlineSectionC(questionText);
      if (markedText !== questionText) {
        question.questionText = markedText;
        updatedCount++;
      }
    }
    
    // For Section D: Find the word to find antonym for
    else if (section === 'D') {
      const markedText = autoUnderlineSectionD(questionText);
      if (markedText !== questionText) {
        question.questionText = markedText;
        updatedCount++;
      }
    }
  });
  
  // Save backup
  const backupPath = filePath.replace('.json', '_backup_pre_underline.json');
  fs.writeFileSync(backupPath, JSON.stringify(data, null, 2), 'utf8');
  
  // Save updated file
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
  
  console.log(`   ✅ Updated: ${updatedCount} questions`);
  console.log(`   ⏭️  Skipped: ${skippedCount} questions (already marked or Section A)`);
  console.log(`   💾 Backup saved to: ${backupPath}`);
  
  return { updated: updatedCount, skipped: skippedCount };
}

function autoUnderlineSectionB(text) {
  // Section B: Find synonyms - underline the key vocabulary word
  // Look for less common/sophisticated words (nouns, adjectives, verbs)
  
  // Common words to SKIP (too basic): is, the, a, an, to, of, in, for, with, etc.
  const commonWords = new Set([
    'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'the', 'a', 'an', 'to', 'of', 'in', 'for', 'with', 'on', 'at', 'by', 'from',
    'have', 'has', 'had', 'do', 'does', 'did',
    'he', 'she', 'it', 'they', 'we', 'you', 'i', 'my', 'his', 'her', 'their', 'our', 'your'
  ]);
  
  // Extract words (3+ letters, alpha only)
  const words = text.match(/\b[a-z]{3,}\b/gi) || [];
  
  // Find the most "sophisticated" word (longer, less common)
  let bestWord = null;
  let bestScore = 0;
  
  for (const word of words) {
    const lower = word.toLowerCase();
    
    // Skip common words
    if (commonWords.has(lower)) continue;
    
    // Score: prefer longer words (more likely to be vocabulary words)
    const score = word.length;
    
    if (score > bestScore) {
      bestScore = score;
      bestWord = word;
    }
  }
  
  if (bestWord) {
    // Replace first occurrence with underlined version
    return text.replace(new RegExp(`\\b${bestWord}\\b`, 'i'), `<u>${bestWord}</u>`);
  }
  
  return text;
}

function autoUnderlineSectionC(text) {
  // Section C: Idioms/expressions - usually a phrase
  // Look for common idiom patterns
  
  const idiomPatterns = [
    /\b(shed crocodile tears)\b/gi,
    /\b(hair stood on end)\b/gi,
    /\b(turn a blind eye)\b/gi,
    /\b(pull someone's leg)\b/gi,
    /\b(break the ice)\b/gi,
    /\b(hit the nail on the head)\b/gi,
    /\b(a piece of cake)\b/gi,
    /\b(cost an arm and a leg)\b/gi,
    /\b(throw in the towel)\b/gi,
    /\b(spill the beans)\b/gi,
    // Add more as needed
  ];
  
  // Try to match known idioms
  for (const pattern of idiomPatterns) {
    if (pattern.test(text)) {
      return text.replace(pattern, '<u>$1</u>');
    }
  }
  
  // If no match, try to find a multi-word phrase (2-4 words)
  // Look for patterns like: verb + article + noun
  const phrasePattern = /\b([a-z]+\s+[a-z]+\s+[a-z]+(?:\s+[a-z]+)?)\b/i;
  const match = text.match(phrasePattern);
  
  if (match) {
    // Take the middle phrase (not the whole sentence)
    const words = text.split(' ');
    if (words.length >= 5) {
      // Underline a 2-3 word phrase in the middle
      const midStart = Math.floor(words.length / 3);
      const midEnd = midStart + 2;
      const phraseToUnderline = words.slice(midStart, midEnd).join(' ');
      return text.replace(phraseToUnderline, `<u>${phraseToUnderline}</u>`);
    }
  }
  
  return text;
}

function autoUnderlineSectionD(text) {
  // Section D: Antonyms - similar to Section B, find the key word
  return autoUnderlineSectionB(text);
}

// Main execution
const filePath = process.argv[2];

if (!filePath) {
  console.log('📝 Add Underline Markers to English Questions');
  console.log('════════════════════════════════════════════\n');
  console.log('Usage: node add_underline_markers.js <json-file-path>');
  console.log('\nExample:');
  console.log('  node add_underline_markers.js ./english_2022_questions.json');
  console.log('\nMarks words that should be underlined using <u>word</u> format');
  console.log('Sections B, C, D will be automatically marked');
  console.log('\n⚠️  IMPORTANT: Review the output and manually adjust if needed!');
  process.exit(0);
}

if (!fs.existsSync(filePath)) {
  console.error(`❌ File not found: ${filePath}`);
  process.exit(1);
}

addUnderlineMarkers(filePath);

console.log('\n⚠️  NEXT STEPS:');
console.log('   1. Review the updated JSON file');
console.log('   2. Manually fix any incorrect underlines');
console.log('   3. Re-import: node import_bece_english.js --file=' + filePath);
