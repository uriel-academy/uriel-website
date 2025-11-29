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

// Parse inline format questions (years 2012-2016, 2024-2025)
function parseInlineQuestions(text) {
    const questions = [];
    const lines = text.split('\n');
    
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        
        // Match: "NUMBER. question text...A. optionB. optionC. optionD. option"
        // More flexible regex to handle various inline formats
        const match = trimmed.match(/^(\d+)\.\s+(.+?)([A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?)$/);
        
        if (match) {
            const questionNumber = parseInt(match[1]);
            const questionText = match[2].trim();
            const optionsText = match[3];
            
            // Extract options from inline format: A. textB. textC. textD. text
            const options = [];
            let currentOption = '';
            let currentLetter = '';
            
            for (let i = 0; i < optionsText.length; i++) {
                const char = optionsText[i];
                const nextChar = optionsText[i + 1];
                
                // Check if this is a new option marker (A., B., C., or D.)
                if (/[A-D]/.test(char) && nextChar === '.') {
                    // Save previous option if exists
                    if (currentLetter && currentOption) {
                        options.push(`${currentLetter}. ${currentOption.trim()}`);
                    }
                    currentLetter = char;
                    currentOption = '';
                    i++; // Skip the dot
                    continue;
                }
                
                currentOption += char;
            }
            
            // Add last option
            if (currentLetter && currentOption) {
                options.push(`${currentLetter}. ${currentOption.trim()}`);
            }
            
            if (options.length === 4) {
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

// Parse inline table format (Q11-Q20, Q31-Q40 in 2012-style files)
function parseInlineTable(text) {
    const questions = [];
    
    // Find question texts for Q11-Q20 (appear before the table)
    const questionTexts = {};
    const part2Match = text.match(/PART II.+?(?=A\s+B\s+C\s+D)/s);
    if (part2Match) {
        const part2Text = part2Match[0];
        // Match: "11. Text...12. Text..." without proper spacing
        const matches = part2Text.matchAll(/(\d+)\.\s+([^.]+?\.{3,})/g);
        for (const match of matches) {
            const qNum = parseInt(match[1]);
            questionTexts[qNum] = match[2].trim();
        }
    }
    
    // Find PART IV cloze questions (Q31-Q40)
    const part4Match = text.match(/PART IV(.+?)(?=\n\d+\.\s+|$)/s);
    if (part4Match) {
        const part4Text = part4Match[1];
        // Extract numbered blanks from passage: "– 31 –", "– 32 –", etc.
        const blankMatches = part4Text.matchAll(/–\s*(\d+)\s*–/g);
        for (const match of blankMatches) {
            const qNum = parseInt(match[1]);
            // Find context around the blank
            const contextMatch = part4Text.match(new RegExp(`([^.]+)–\\s*${qNum}\\s*–([^.]+)`, 's'));
            if (contextMatch) {
                questionTexts[qNum] = `${contextMatch[1].trim().slice(-30)} _____ ${contextMatch[2].trim().slice(0, 30)}`;
            }
        }
    }
    
    // Find tables with inline format
    // Pattern: "A B C D" followed by "11. option option option option12. option..."
    // Handle both "\n31." and "31." (with or without newline after header)
    const tableRegex = /A\s+B\s+C\s+D\s*\n?\s*(\d+\.[\s\S]+?)(?=\n\n\n|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    for (const tableMatch of tableMatches) {
        const tableText = tableMatch[1];
        
        // Extract question numbers and options
        // Format: "11. opt1 opt2 opt3 opt412. opt1 opt2 opt3 opt4"
        const questionRegex = /(\d+)\.\s*([^\d]+?)(?=\d+\.|$)/g;
        const questionMatches = tableText.matchAll(questionRegex);
        
        for (const qMatch of questionMatches) {
            const qNum = parseInt(qMatch[1]);
            const optionsText = qMatch[2].trim();
            
            // Try to extract exactly 4 options
            // For most questions, options are single words separated by spaces
            // For some, options are multi-word phrases (e.g., "la bibliothèque")
            const words = optionsText.split(/\s+/).filter(p => p && p.length > 0);
            
            let options = [];
            
            // If we have exactly 4 words, it's simple
            if (words.length === 4) {
                options = words.map((w, i) => `${String.fromCharCode(65 + i)}. ${w}`);
            }
            // If more than 4, we need to group them intelligently
            else if (words.length > 4) {
                // Strategy: Look for French articles (la, le, l', les, un, une, des, etc.)
                // that typically start a new option
                const articleMarkers = ['la', 'le', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux'];
                const optionGroups = [];
                let currentOption = [];
                
                for (let i = 0; i < words.length; i++) {
                    const word = words[i];
                    const isArticle = articleMarkers.includes(word.toLowerCase()) || word.toLowerCase().startsWith("l'");
                    
                    // Start a new option if we hit an article and already have words
                    if (isArticle && currentOption.length > 0 && optionGroups.length < 3) {
                        optionGroups.push(currentOption.join(' '));
                        currentOption = [word];
                    } else {
                        currentOption.push(word);
                    }
                }
                
                // Add final option
                if (currentOption.length > 0) {
                    optionGroups.push(currentOption.join(' '));
                }
                
                // If we got exactly 4 groups, use them
                if (optionGroups.length === 4) {
                    options = optionGroups.map((opt, i) => `${String.fromCharCode(65 + i)}. ${opt}`);
                } else {
                    // Fallback: just take first 4 words
                    options = words.slice(0, 4).map((w, i) => `${String.fromCharCode(65 + i)}. ${w}`);
                }
            }
            else if (words.length > 0 && words.length < 4) {
                // Less than 4 words - just use what we have
                options = words.map((w, i) => `${String.fromCharCode(65 + i)}. ${w}`);
            }
            
            if (options.length === 4) {
                const questionText = questionTexts[qNum] || `Complete the blank in question ${qNum}`;
                
                questions.push({
                    questionNumber: qNum,
                    question: questionText,
                    options
                });
            }
        }
    }
    
    return questions;
}

// Parse columnar table format (years 2015-2016)
// Format: "A.    B.    C.    D." header followed by rows like "11. opt1  opt2  opt3  opt4"
function parseColumnarTable(text) {
    const questions = [];
    
    // Find question texts from PART II and PART IV
    const questionTexts = {};
    
    // PART II questions (Q11-Q20)
    const part2Match = text.match(/PART II.+?(?=A\.\s+B\.\s+C\.\s+D\.)/s);
    if (part2Match) {
        const part2Text = part2Match[0];
        const matches = part2Text.matchAll(/(\d+)\.\s+([^.]+?\.{3,})/g);
        for (const match of matches) {
            const qNum = parseInt(match[1]);
            questionTexts[qNum] = match[2].trim();
        }
    }
    
    // PART IV cloze questions (Q31-Q40)
    const part4Match = text.match(/PART IV(.+?)(?=A\.\s+B\.\s+C\.\s+D\.)/s);
    if (part4Match) {
        const part4Text = part4Match[1];
        const blankMatches = part4Text.matchAll(/–\s*(\d+)\s*–/g);
        for (const match of blankMatches) {
            const qNum = parseInt(match[1]);
            const contextMatch = part4Text.match(new RegExp(`([^.]{0,30})–\\s*${qNum}\\s*–([^.]{0,30})`, 's'));
            if (contextMatch) {
                questionTexts[qNum] = `${contextMatch[1].trim()} _____ ${contextMatch[2].trim()}`;
            }
        }
    }
    
    // Find columnar tables: "A.    B.    C.    D." followed by rows
    const tableRegex = /A\.\s+B\.\s+C\.\s+D\.(.+?)(?=PART|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    for (const tableMatch of tableMatches) {
        const tableText = tableMatch[1];
        
        // Parse rows using regex to handle multi-line rows
        const rowMatches = tableText.matchAll(/(\d+)\.\s+(.+?)(?=\d+\.|$)/gs);
        
        for (const rowMatch of rowMatches) {
            const qNum = parseInt(rowMatch[1]);
            const optionsLine = rowMatch[2];
            
            // Split by multiple spaces (columns are separated by whitespace)
            const parts = optionsLine.split(/\s{2,}/).filter(p => p.trim());
            
            if (parts.length >= 4) {
                const options = [
                    `A. ${parts[0].trim()}`,
                    `B. ${parts[1].trim()}`,
                    `C. ${parts[2].trim()}`,
                    `D. ${parts[3].trim()}`
                ];
                
                const questionText = questionTexts[qNum] || `Complete the blank in question ${qNum}`;
                
                questions.push({
                    questionNumber: qNum,
                    question: questionText,
                    options
                });
            }
        }
    }
    
    return questions;
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
    
    // Years 2024-2025 use a different format
    if (year === '2024' || year === '2025') {
        return parse2024Format(text).sort((a, b) => a.questionNumber - b.questionNumber);
    }
    
    const clozeQuestions = parseClozekQuestions(text);
    const fillInBlankQuestions = parseFillInBlankQuestions(text);
    const standardQuestions = parseStandardQuestions(text);
    const inlineQuestions = parseInlineQuestions(text);
    const inlineTableQuestions = parseInlineTable(text);
    const columnarTableQuestions = parseColumnarTable(text);
    
    const allQuestions = [
        ...clozeQuestions, 
        ...fillInBlankQuestions, 
        ...standardQuestions, 
        ...inlineQuestions,
        ...inlineTableQuestions,
        ...columnarTableQuestions
    ];
    
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
        
        // Special case: Add Q26 for 2015 (inline format on separate line)
        if (year === '2015' && !questions.find(q => q.questionNumber === 26)) {
            questions.push({
                questionNumber: 26,
                question: '– Pourquoi son corps est couvert de sueur ? …………..– Parce qu\'il est …………………',
                options: [
                    'A. paresseux',
                    'B. méchant',
                    'C. fâché',
                    'D. travailleur'
                ]
            });
            questions.sort((a, b) => a.questionNumber - b.questionNumber);
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
            const docRef = db.collection('bece_mcq').doc(docId);
            
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
