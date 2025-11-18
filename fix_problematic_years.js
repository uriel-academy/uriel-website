const mammoth = require('mammoth');
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function fixSpecificYears() {
  console.log('🔧 Fixing specific problematic years...\n');
  
  const yearsToFix = ['2025', '2024', '2023', '2021', '2022'];
  
  for (const year of yearsToFix) {
    console.log(`Processing ${year}...`);
    const filePath = `./assets/Mathematics/bece mathematics ${year} questions.docx`;
    
    try {
      const result = await mammoth.extractRawText({ path: filePath });
      const questions = parseWithContext(result.value, year);
      
      console.log(`  Found ${questions.length} questions`);
      
      for (const q of questions) {
        const snapshot = await db.collection('questions')
          .where('year', '==', year)
          .where('subject', '==', 'mathematics')
          .where('questionNumber', '==', q.questionNumber)
          .limit(1)
          .get();
        
        if (!snapshot.empty) {
          await snapshot.docs[0].ref.update({
            questionText: q.question,
            options: q.optionsArray,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
      
      console.log(`  ✅ Updated ${year}\n`);
    } catch (error) {
      console.error(`  ❌ Error with ${year}:`, error.message);
    }
  }
  
  console.log('✨ Done!');
  process.exit(0);
}

function parseWithContext(text, year) {
  const questions = [];
  const lines = text.split('\n').map(l => l.trim());
  
  // Find all question numbers first
  const questionIndices = [];
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].match(/^\d+\.$/)) {
      questionIndices.push(i);
    }
  }
  
  // Process each question
  for (let qIdx = 0; qIdx < questionIndices.length; qIdx++) {
    const startIdx = questionIndices[qIdx];
    const endIdx = qIdx < questionIndices.length - 1 ? questionIndices[qIdx + 1] : lines.length;
    
    const questionNumber = parseInt(lines[startIdx].replace('.', ''));
    const questionLines = lines.slice(startIdx + 1, endIdx);
    
    // Find option markers (A., B., C., D., E.)
    const optionIndices = [];
    for (let i = 0; i < questionLines.length; i++) {
      if (questionLines[i].match(/^[A-E]\.$/)) {
        optionIndices.push(i);
      }
    }
    
    if (optionIndices.length === 0) continue;
    
    // Question text is everything before first option
    const questionText = questionLines
      .slice(0, optionIndices[0])
      .filter(l => l)
      .join(' ')
      .trim();
    
    // Extract options
    const optionsArray = [];
    for (let i = 0; i < optionIndices.length; i++) {
      const optionLetter = questionLines[optionIndices[i]].replace('.', '');
      const optionStart = optionIndices[i] + 1;
      const optionEnd = i < optionIndices.length - 1 ? optionIndices[i + 1] : questionLines.length;
      
      const optionText = questionLines
        .slice(optionStart, optionEnd)
        .filter(l => l)
        .join(' ')
        .trim();
      
      if (optionText) {
        optionsArray.push(`${optionLetter}. ${optionText}`);
      }
    }
    
    if (questionText && optionsArray.length >= 2) {
      questions.push({
        questionNumber,
        question: questionText,
        optionsArray
      });
    }
  }
  
  return questions;
}

fixSpecificYears();
