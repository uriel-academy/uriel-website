const admin = require('firebase-admin');
const mammoth = require('mammoth');
const fs = require('fs');

// Initialize Firebase
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Parse French answer key
async function parseFrenchAnswers() {
    const result = await mammoth.extractRawText({ 
        path: 'assets/bece french/bece  french 1990-2016-2024-2025 answers.docx' 
    });
    
    const text = result.value;
    const lines = text.split('\n').map(l => l.trim()).filter(l => l);
    
    const answersByYear = {};
    let currentYear = null;
    
    for (const line of lines) {
        // Check if line is a year
        if (/^\d{4}$/.test(line)) {
            currentYear = line;
            answersByYear[currentYear] = {};
            continue;
        }
        
        // Check if line is a question-answer pair (e.g., "1. C" or "1.C")
        const match = line.match(/^(\d+)\.?\s*([A-D])$/);
        if (match && currentYear) {
            const qNum = parseInt(match[1]);
            const answer = match[2];
            answersByYear[currentYear][qNum] = answer;
        }
    }
    
    return answersByYear;
}

// Parse cloze/passage questions (Q1-Q10)
function parseClozekQuestions(text) {
    const questions = [];
    
    // Check if there's a cloze passage
    if (!/The passage below has.*?numbered spaces/i.test(text)) {
        return questions;
    }
    
    // Find the options table - it appears after the passage
    // Format: "A B C D" header followed by rows like "1. option1 option2 option3 option4"
    // Only capture until we see question 11 or end
    const tableMatch = text.match(/A\s+B\s+C\s+D\s*\n([\s\S]*?)(?=\n\s*11\.|$)/);
    if (!tableMatch) return questions;
    
    const tableText = tableMatch[1];
    const tableLines = tableText.split('\n').filter(l => l.trim());
    
    // Only process rows with question numbers 1-10
    let foundQuestions = 0;
    
    for (const line of tableLines) {
        const trimmed = line.trim();
        
        // Skip header row
        if (trimmed === 'A B C D' || !trimmed) continue;
        
        // Stop if we've found all 10 questions
        if (foundQuestions >= 10) break;
        
        // Match rows like: "1. son sa ton ta" or "1 son sa ton ta"
        const parts = trimmed.split(/\s+/);
        if (parts.length >= 5) {
            // First part should be number or number.
            const firstPart = parts[0].replace('.', '');
            if (/^\d+$/.test(firstPart)) {
                const questionNumber = parseInt(firstPart);
                
                // Only process questions 1-10
                if (questionNumber < 1 || questionNumber > 10) continue;
                
                foundQuestions++;
                
                const options = [
                    `A. ${parts[1]}`,
                    `B. ${parts[2]}`,
                    `C. ${parts[3]}`,
                    `D. ${parts[4]}`
                ];
                
                // Find context in passage
                const blankPattern = new RegExp(`([^.]*?)___+${questionNumber}___+([^.]*)`, 's');
                const blankMatch = text.match(blankPattern);
                let questionText = `Complete the blank ___${questionNumber}___`;
                
                if (blankMatch) {
                    const before = blankMatch[1].trim().split(/[.!?]/).pop().trim();
                    const after = blankMatch[2].trim().split(/[.!?]/)[0].trim();
                    questionText = `${before} ______ ${after}`;
                }
                
                questions.push({
                    questionNumber,
                    question: questionText,
                    options
                });
            }
        }
    }
    
    return questions;
}

// Parse fill-in-the-blank questions Q21-Q30 (questions with separate options table)
// Also handles Q11-Q20 and Q31-Q40 table formats in some years
function parseFillInBlankQuestions(text) {
    const questions = [];
    
    // Find Q21-Q30, Q11-Q20, Q31-Q40 questions (fill-in-the-blank format)
    // They appear as: "21. Question text with ……."
    const lines = text.split('\n');
    const questionTexts = {};
    
    for (const line of lines) {
        const trimmed = line.trim();
        const qMatch = trimmed.match(/^(1[1-9]|2[0-9]|3[0-9]|40)\.\s+(.+)/);
        if (qMatch && (qMatch[2].includes('…') || qMatch[2].length < 100)) {
            const qNum = parseInt(qMatch[1]);
            questionTexts[qNum] = qMatch[2];
        }
    }
    
    // Find all "A B C D" tables
    const tableMatches = [];
    const regex = /A\s+B\s+C\s+D/g;
    let match;
    while ((match = regex.exec(text)) !== null) {
        tableMatches.push(match.index);
    }
    
    if (tableMatches.length === 0) return questions;
    
    // Process each table
    for (let tableIdx = 0; tableIdx < tableMatches.length; tableIdx++) {
        const tableStart = tableMatches[tableIdx] + 9; // Skip "A B C D" itself
        const tableEnd = tableIdx < tableMatches.length - 1 
            ? tableMatches[tableIdx + 1]
            : text.indexOf('Read the passage', tableStart);
        
        const tableText = tableEnd > tableStart
            ? text.substring(tableStart, tableEnd)
            : text.substring(tableStart);
        
        const tableLines = tableText.split('\n').filter(l => l.trim());
        
        for (const line of tableLines) {
            const trimmed = line.trim();
            
            if (trimmed === 'A B C D' || !trimmed) continue;
            
            const parts = trimmed.split(/\s+/);
            if (parts.length >= 5) {
                const firstPart = parts[0].replace('.', '');
                if (/^\d+$/.test(firstPart)) {
                    const questionNumber = parseInt(firstPart);
                    
                    // Only process Q11-Q20, Q21-Q30, Q31-Q40
                    if (questionNumber < 11 || questionNumber > 40) continue;
                    
                    const options = [
                        `A. ${parts[1]}`,
                        `B. ${parts[2]}`,
                        `C. ${parts[3]}`,
                        `D. ${parts[4]}`
                    ];
                    
                    const questionText = questionTexts[questionNumber] || `Complete blank in question ${questionNumber}`;
                    
                    questions.push({
                        questionNumber,
                        question: questionText,
                        options
                    });
                }
            }
        }
    }
    
    return questions;
}

// Parse standard MCQ questions (all questions)
function parseStandardQuestions(text) {
    const questions = [];
    const lines = text.split('\n');
    
    let currentQuestion = null;
    let currentOptions = [];
    let skipMode = false; // Skip lines in "A B C D" tables
    
    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trim();
        
        // Check if we're entering a table section (A B C D header)
        if (trimmed === 'A B C D') {
            skipMode = true;
            continue;
        }
        
        // Exit skip mode when we see "Read the passage" or other section markers
        if (skipMode && (/^Read the passage/i.test(trimmed) || /^For each question/i.test(trimmed) || trimmed.length > 80)) {
            skipMode = false;
        }
        
        // Skip lines while in table mode
        if (skipMode) continue;
        
        // Skip empty lines
        if (!trimmed) continue;
        
        // Question number
        const questionMatch = trimmed.match(/^(\d+)\.\s+(.+)/);
        if (questionMatch) {
            const qNum = parseInt(questionMatch[1]);
            
            // Save previous question
            if (currentQuestion && currentOptions.length === 4) {
                questions.push({
                    questionNumber: currentQuestion.number,
                    question: currentQuestion.text,
                    options: currentOptions
                });
            }
            
            // Start new question
            currentQuestion = {
                number: qNum,
                text: questionMatch[2]
            };
            currentOptions = [];
            continue;
        }
        
        // Option line
        const optionMatch = trimmed.match(/^([A-D])\.?\s*(.*)$/);
        if (optionMatch && currentQuestion) {
            const optText = optionMatch[2].trim();
            // Only add if option text is not empty
            if (optText) {
                currentOptions.push(`${optionMatch[1]}. ${optText}`);
                
                // If we have all 4 options, save the question
                if (currentOptions.length === 4) {
                    questions.push({
                        questionNumber: currentQuestion.number,
                        question: currentQuestion.text,
                        options: currentOptions
                    });
                    currentQuestion = null;
                    currentOptions = [];
                }
            }
        }
    }
    
    return questions;
}

// Main parser
async function parseFrenchQuestions(year, filePath) {
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    
    const clozeQuestions = parseClozekQuestions(text);
    const fillInBlankQuestions = parseFillInBlankQuestions(text);
    const standardQuestions = parseStandardQuestions(text);
    
    const allQuestions = [...clozeQuestions, ...fillInBlankQuestions, ...standardQuestions];
    
    // Deduplicate by question number (some files have duplicate tables)
    const uniqueQuestions = [];
    const seenNumbers = new Set();
    
    for (const q of allQuestions) {
        if (!seenNumbers.has(q.questionNumber)) {
            uniqueQuestions.push(q);
            seenNumbers.add(q.questionNumber);
        }
    }
    
    return uniqueQuestions.sort((a, b) => a.questionNumber - b.questionNumber);
}

// Import to Firestore
async function importFrenchMCQ() {
    console.log('=== IMPORTING FRENCH MCQ TO FIRESTORE ===\n');
    
    // Parse answers
    console.log('Parsing answer key...');
    const answersByYear = await parseFrenchAnswers();
    const yearsWithAnswers = Object.keys(answersByYear).sort();
    console.log(`Found answers for ${yearsWithAnswers.length} years: ${yearsWithAnswers.join(', ')}\n`);
    
    const stats = {
        totalImported: 0,
        byYear: {},
        errors: []
    };
    
    // Process each year
    for (const year of yearsWithAnswers) {
        // Skip 1990 (no MCQ)
        if (year === '1990') continue;
        
        console.log(`\n=== Processing ${year} ===`);
        
        // Find question file
        const possibleFiles = [
            `assets/bece french/bece french ${year} questions.docx`,
            `assets/bece french/bece  french ${year} questions.docx`,
            `assets/bece french/bece  french ${year}  questions.docx`
        ];
        
        let filePath = null;
        for (const file of possibleFiles) {
            if (fs.existsSync(file)) {
                filePath = file;
                break;
            }
        }
        
        if (!filePath) {
            console.log(`  ✗ File not found`);
            stats.errors.push({ year, error: 'File not found' });
            continue;
        }
        
        // Parse questions
        console.log(`  Parsing: ${filePath}`);
        const questions = await parseFrenchQuestions(year, filePath);
        console.log(`  Found ${questions.length} questions`);
        
        if (questions.length === 0) {
            console.log(`  ✗ No questions found`);
            continue;
        }
        
        // Import to Firestore
        const batch = db.batch();
        let imported = 0;
        
        for (const q of questions) {
            const answer = answersByYear[year][q.questionNumber];
            
            if (!answer) {
                console.log(`  ⚠️  No answer for Q${q.questionNumber}`);
                continue;
            }
            
            const docId = `french_${year}_q${q.questionNumber}`;
            const docRef = db.collection('questions').doc(docId);
            
            batch.set(docRef, {
                id: docId,
                subject: 'french',
                subjectDisplay: 'French',
                year: year,
                questionNumber: q.questionNumber,
                question: q.question,
                options: q.options,
                correctAnswer: answer,
                type: 'multipleChoice',
                examType: 'bece',
                difficulty: 'medium',
                topics: [],
                explanation: `French MCQ from BECE ${year}`,
                createdBy: 'system_import',
                isActive: true,
                metadata: {
                    source: `BECE ${year}`,
                    importDate: new Date().toISOString(),
                    verified: true
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            imported++;
        }
        
        await batch.commit();
        console.log(`  ✓ Imported ${imported} questions`);
        
        stats.totalImported += imported;
        stats.byYear[year] = imported;
    }
    
    console.log('\n=== IMPORT COMPLETE ===');
    console.log(`Total imported: ${stats.totalImported}`);
    console.log(`\nBy Year:`);
    Object.keys(stats.byYear).forEach(year => {
        console.log(`  ${year}: ${stats.byYear[year]} questions`);
    });
    
    if (stats.errors.length > 0) {
        console.log(`\nErrors: ${stats.errors.length}`);
        stats.errors.forEach(e => {
            console.log(`  ${e.year}: ${e.error}`);
        });
    }
    
    process.exit(0);
}

importFrenchMCQ().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
