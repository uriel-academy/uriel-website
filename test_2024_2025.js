const admin = require('firebase-admin');
const mammoth = require('mammoth');
const fs = require('fs');
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

// Parse 2024-2025 format: two patterns:
// Pattern 1: "...passage text.1." on one line, then "Question?A. opt1..." on next
// Pattern 2: "N." alone on a line, then "Question?A. opt1..." on next non-empty line
function parse2024Format(text) {
    const questions = [];
    const lines = text.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        
        // Pattern 1: Check if line ENDS with "N." (e.g., "...transport.1.")
        const endMatch = line.match(/(\d+)\.\s*$/);
        if (endMatch) {
            const qNum = parseInt(endMatch[1]);
            
            // Find first non-empty line after
            let contentLine = i + 1;
            while (contentLine < lines.length && !lines[contentLine].trim()) {
                contentLine++;
            }
            
            if (contentLine < lines.length) {
                const nextLine = lines[contentLine].trim();
                
                // Check for inline format
                const inlineMatch = nextLine.match(/^(.+?)([A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?)$/);
                
                if (inlineMatch) {
                    const questionText = inlineMatch[1].trim();
                    const optionsText = inlineMatch[2];
                    
                    const options = [];
                    const optMatches = optionsText.matchAll(/([A-D])\.\s+(.+?)(?=[A-D]\.|$)/g);
                    
                    for (const optMatch of optMatches) {
                        options.push(`${optMatch[1]}. ${optMatch[2].trim()}`);
                    }
                    
                    if (options.length === 4) {
                        questions.push({
                            questionNumber: qNum,
                            question: questionText,
                            options
                        });
                    }
                }
            }
            continue;
        }
        
        // Pattern 2: Match "N." alone on a line
        const aloneMatch = line.match(/^(\d+)\.\s*$/);
        
        if (aloneMatch) {
            const qNum = parseInt(aloneMatch[1]);
            
            // Find first non-empty line after the question number
            let contentLine = i + 1;
            while (contentLine < lines.length && !lines[contentLine].trim()) {
                contentLine++;
            }
            
            if (contentLine < lines.length) {
                const nextLine = lines[contentLine].trim();
                
                // Check if next line contains the inline format (question + options)
                const inlineMatch = nextLine.match(/^(.+?)([A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?[A-D]\.\s+.+?)$/);
                
                if (inlineMatch) {
                    const questionText = inlineMatch[1].trim();
                    const optionsText = inlineMatch[2];
                    
                    // Parse options by splitting on letter markers
                    const options = [];
                    const optMatches = optionsText.matchAll(/([A-D])\.\s+(.+?)(?=[A-D]\.|$)/g);
                    
                    for (const optMatch of optMatches) {
                        options.push(`${optMatch[1]}. ${optMatch[2].trim()}`);
                    }
                    
                    if (options.length === 4) {
                        questions.push({
                            questionNumber: qNum,
                            question: questionText,
                            options
                        });
                    }
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
    
    const questions = parse2024Format(text);
    
    return questions.sort((a, b) => a.questionNumber - b.questionNumber);
}

// Import questions for specific years
async function importYears() {
    const years = ['2024', '2025'];
    
    // Parse answer key first
    console.log('Parsing French answer key...');
    const answers = await parseFrenchAnswers();
    
    for (const year of years) {
        console.log(`\nProcessing year ${year}...`);
        
        const filePath = `assets/bece french/bece french ${year} questions.docx`;
        
        if (!fs.existsSync(filePath)) {
            console.log(`File not found: ${filePath}`);
            continue;
        }
        
        const questions = await parseFrenchQuestions(year, filePath);
        console.log(`Parsed ${questions.length} questions from ${year}`);
        
        // Display first 3 questions
        console.log('\nFirst 3 questions:');
        questions.slice(0, 3).forEach(q => {
            console.log(`\nQ${q.questionNumber}: ${q.question}`);
            q.options.forEach(opt => console.log(`  ${opt}`));
            console.log(`  Correct: ${answers[year]?.[q.questionNumber] || 'N/A'}`);
        });
        
        // Import to Firestore
        const batch = db.batch();
        let count = 0;
        
        for (const q of questions) {
            const docId = `french_${year}_q${q.questionNumber}`;
            const docRef = db.collection('bece_mcq').doc(docId);
            
            batch.set(docRef, {
                id: docId,
                subject: 'french',
                year: year,
                questionNumber: q.questionNumber,
                question: q.question,
                options: q.options,
                correctAnswer: answers[year]?.[q.questionNumber] || '',
                type: 'multipleChoice',
                examType: 'bece'
            });
            
            count++;
            
            // Commit in batches of 500
            if (count % 500 === 0) {
                await batch.commit();
                console.log(`Committed ${count} questions...`);
            }
        }
        
        if (count % 500 !== 0) {
            await batch.commit();
        }
        
        console.log(`✓ Imported ${count} questions for ${year}`);
    }
    
    console.log('\n✓ Import complete');
    process.exit(0);
}

importYears().catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
