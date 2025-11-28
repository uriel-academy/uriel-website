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
    let questionNumber = 0;
    
    for (const line of lines) {
        // Check if line is a year
        if (/^\d{4}$/.test(line)) {
            currentYear = line;
            answersByYear[currentYear] = {};
            questionNumber = 0;
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

// Parse a French question file
async function parseFrenchQuestions(year, filePath) {
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    const lines = text.split('\n');
    
    const questions = [];
    
    // PART 1: Parse cloze passage questions (Q1-Q10)
    // These are in format: numbered blanks in passage, then options in table
    const clozeMatch = text.match(/The passage below.*?(?=For each question|11\.|$)/s);
    if (clozeMatch) {
        const clozeSection = clozeMatch[0];
        
        // Extract the passage text
        const passageMatch = clozeSection.match(/(?:A l'école|Du lundi|Ce matin|Hier soir|Mon ami|La famille|Au march).*?(?=\d+\s+[A-D]\s+[A-D]\s+[A-D]\s+[A-D])/s);
        const passage = passageMatch ? passageMatch[0].trim() : '';
        
        // Extract options table
        const optionsTableMatch = clozeSection.match(/\d+\s+[A-D]\s+.*?(?=For each|11\.|$)/s);
        if (optionsTableMatch) {
            const tableText = optionsTableMatch[0];
            const tableLines = tableText.split('\n').filter(l => l.trim());
            
            // Parse each row of the table
            for (const line of tableLines) {
                const rowMatch = line.match(/^(\d+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/);
                if (rowMatch) {
                    const questionNumber = parseInt(rowMatch[1]);
                    const options = [
                        `A. ${rowMatch[2]}`,
                        `B. ${rowMatch[3]}`,
                        `C. ${rowMatch[4]}`,
                        `D. ${rowMatch[5]}`
                    ];
                    
                    // Extract context from passage around blank number
                    const blankPattern = new RegExp(`([^.]*?)____${questionNumber}____([^.]*)`, 's');
                    const blankMatch = passage.match(blankPattern);
                    const contextBefore = blankMatch ? blankMatch[1].trim().split(/[.!?]/).pop() : '';
                    const contextAfter = blankMatch ? blankMatch[2].trim().split(/[.!?]/)[0] : '';
                    
                    questions.push({
                        questionNumber,
                        question: `${contextBefore.trim()} ______ ${contextAfter.trim()}`,
                        options,
                        passageContext: passage
                    });
                }
            }
        }
    }
    
    // PART 2: Parse standard MCQ questions (Q11-Q40)
    let currentQuestion = null;
    let currentOptions = [];
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        
        // Skip empty lines and headers
        if (!line || /^For each question/.test(line) || /^Choose from/i.test(line)) {
            continue;
        }
        
        // Check for question number at start of line (e.g., "11. Pendant la...")
        const questionMatch = line.match(/^(\d+)\.\s+(.+)/);
        if (questionMatch) {
            const qNum = parseInt(questionMatch[1]);
            
            // Only process if it's Q11 or higher (standard MCQ format)
            if (qNum >= 11) {
                // Save previous question if exists
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
            }
            continue;
        }
        
        // Check for option (e.g., "A. de" or "A.de")
        const optionMatch = line.match(/^([A-D])\.?\s*(.*)$/);
        if (optionMatch && currentQuestion) {
            const letter = optionMatch[1];
            const text = optionMatch[2].trim();
            currentOptions.push(`${letter}. ${text}`);
            
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
    
    return questions;
}
            currentOptions.push(`${letter}. ${text}`);
            
            // If we have 4 options, question is complete
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
    
    return questions;
}

// Import French MCQ to Firestore
async function importFrenchMCQ() {
    console.log('=== IMPORTING FRENCH MCQ TO FIRESTORE ===\n');
    
    // Parse answer key
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
        console.log(`\n=== Processing ${year} ===`);
        
        // Find the question file
        const possibleFiles = [
            `assets/bece french/bece  french ${year} questions.docx`,
            `assets/bece french/bece  french ${year}  questions.docx`,
            `assets/bece french/bece french ${year} questions.docx`,
            `assets/bece french/bece french ${year}  questions.docx`
        ];
        
        let filePath = null;
        for (const file of possibleFiles) {
            if (fs.existsSync(file)) {
                filePath = file;
                break;
            }
        }
        
        if (!filePath) {
            console.log(`  ✗ Question file not found`);
            stats.errors.push({ year, error: 'File not found' });
            continue;
        }
        
        // Parse questions
        console.log(`  Parsing questions from: ${filePath}`);
        const questions = await parseFrenchQuestions(year, filePath);
        console.log(`  Found ${questions.length} questions`);
        
        if (questions.length === 0) {
            console.log(`  ✗ No MCQ questions found`);
            continue;
        }
        
        const answers = answersByYear[year];
        let imported = 0;
        
        // Import to Firestore
        const batch = db.batch();
        
        for (const q of questions) {
            const answer = answers[q.questionNumber];
            if (!answer) {
                console.log(`  ⚠️  No answer for Q${q.questionNumber}`);
                continue;
            }
            
            const docId = `french_${year}_q${q.questionNumber}`;
            const docRef = db.collection('questions').doc(docId);
            
            batch.set(docRef, {
                subject: 'french',
                year: year,
                questionNumber: q.questionNumber,
                type: 'multipleChoice',
                question: q.question,
                options: q.options,
                correctAnswer: answer,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            imported++;
        }
        
        await batch.commit();
        stats.totalImported += imported;
        stats.byYear[year] = imported;
        console.log(`  ✓ Imported ${imported} questions`);
    }
    
    // Summary
    console.log('\n\n=== IMPORT COMPLETE ===');
    console.log(`Total questions imported: ${stats.totalImported}`);
    console.log(`Years processed: ${Object.keys(stats.byYear).length}`);
    
    if (stats.errors.length > 0) {
        console.log(`\nErrors: ${stats.errors.length}`);
        stats.errors.forEach(e => {
            console.log(`  ${e.year}: ${e.error}`);
        });
    }
    
    console.log('\nBreakdown by year:');
    for (const [year, count] of Object.entries(stats.byYear)) {
        console.log(`  ${year}: ${count} questions`);
    }
    
    // Save report
    fs.writeFileSync(
        'french_mcq_import_report.json',
        JSON.stringify(stats, null, 2)
    );
    console.log('\nReport saved to: french_mcq_import_report.json');
    
    process.exit(0);
}

importFrenchMCQ().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
