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

// Parse cloze-style questions from table (Q1-Q10)
function parseClozekQuestions(text) {
    const questions = [];
    
    // Find the first "A B C D" table (for Q1-Q10)
    const tableMatch = text.match(/A\s+B\s+C\s+D\s*\n([\s\S]*?)(?=\n\s*11\.|$)/);
    
    if (!tableMatch) return questions;
    
    const tableText = tableMatch[1];
    
    // Extract options for each question number
    const lines = tableText.split('\n');
    const questionData = {};
    
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        
        // Match patterns like "1. ami amis amies amer"
        const match = trimmed.match(/^(\d+)\.\s+(.+)/);
        if (match) {
            const qNum = parseInt(match[1]);
            const optionsText = match[2];
            
            // Split options by whitespace, but group multi-word phrases
            const words = optionsText.trim().split(/\s+/);
            const options = [];
            let currentOption = '';
            
            for (const word of words) {
                if (currentOption && (word.match(/^(le|la|les|un|une|des|l'|de|du|au|aux)\b/i))) {
                    // Start of a new multi-word phrase
                    options.push(currentOption.trim());
                    currentOption = word;
                } else if (currentOption) {
                    currentOption += ' ' + word;
                } else {
                    currentOption = word;
                }
            }
            
            if (currentOption) {
                options.push(currentOption.trim());
            }
            
            // Take first 4 options
            if (options.length >= 4) {
                questionData[qNum] = options.slice(0, 4).map((opt, i) => 
                    `${String.fromCharCode(65 + i)}. ${opt}`
                );
            }
        }
    }
    
    // Find cloze passages with ___N___ format
    const clozeRegex = /___(\d+)___/g;
    let clozeMatch;
    
    while ((clozeMatch = clozeRegex.exec(text)) !== null) {
        const qNum = parseInt(clozeMatch[1]);
        
        if (questionData[qNum]) {
            // Extract context around the blank
            const start = Math.max(0, clozeMatch.index - 100);
            const end = Math.min(text.length, clozeMatch.index + 100);
            const context = text.substring(start, end);
            
            // Find the sentence containing the blank
            const sentences = context.split(/[.!?]+/);
            const blankSentence = sentences.find(s => s.includes(`___${qNum}___`));
            
            if (blankSentence) {
                questions.push({
                    questionNumber: qNum,
                    question: blankSentence.trim().replace(`___${qNum}___`, '_____'),
                    options: questionData[qNum]
                });
            }
        }
    }
    
    return questions;
}

// Parse fill-in-blank questions from "A B C D" tables (Q11-Q40)
function parseFillInBlankQuestions(text) {
    const questions = [];
    
    // Find ALL "A B C D" tables in the document
    const tableRegex = /A\s+B\s+C\s+D\s*\n?\s*([\s\S]+?)(?=\n\n\n|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    for (const tableMatch of tableMatches) {
        const tableText = tableMatch[1];
        
        // Parse each line in the table
        const lines = tableText.split('\n');
        
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            
            // Match patterns like "11. ami amis amies amer"
            const match = trimmed.match(/^(\d+)\.\s+(.+)/);
            if (match) {
                const qNum = parseInt(match[1]);
                const optionsText = match[2];
                
                // Skip if Q1-Q10 (handled by cloze parser)
                if (qNum <= 10) continue;
                
                // Split options, handling multi-word phrases
                const words = optionsText.trim().split(/\s+/);
                const options = [];
                let currentOption = '';
                
                for (const word of words) {
                    if (currentOption && (word.match(/^(le|la|les|un|une|des|l'|de|du|au|aux)\b/i))) {
                        options.push(currentOption.trim());
                        currentOption = word;
                    } else if (currentOption) {
                        currentOption += ' ' + word;
                    } else {
                        currentOption = word;
                    }
                }
                
                if (currentOption) {
                    options.push(currentOption.trim());
                }
                
                if (options.length >= 4) {
                    const formattedOptions = options.slice(0, 4).map((opt, i) => 
                        `${String.fromCharCode(65 + i)}. ${opt}`
                    );
                    
                    // Find question text
                    let questionText = '';
                    
                    // For Q11-Q20, look in PART II section
                    if (qNum >= 11 && qNum <= 20) {
                        const part2Match = text.match(/PART II.+?(?=PART III|PART IV|$)/s);
                        if (part2Match) {
                            const qTextMatch = part2Match[0].match(new RegExp(`${qNum}\\.\\s+([^.]+?\\.{3,})`));
                            if (qTextMatch) {
                                questionText = qTextMatch[1].trim();
                            }
                        }
                    }
                    
                    // For Q31-Q40, look for cloze blanks in PART IV
                    if (qNum >= 31 && qNum <= 40) {
                        const blankMatch = text.match(new RegExp(`–\\s*${qNum}\\s*–`));
                        if (blankMatch) {
                            const start = Math.max(0, blankMatch.index - 50);
                            const end = Math.min(text.length, blankMatch.index + 50);
                            const context = text.substring(start, end);
                            questionText = context.replace(new RegExp(`–\\s*${qNum}\\s*–`), '_____').trim();
                        }
                    }
                    
                    questions.push({
                        questionNumber: qNum,
                        question: questionText || `Complete the blank in question ${qNum}`,
                        options: formattedOptions
                    });
                }
            }
        }
    }
    
    return questions;
}

// Parse standard questions (Q/A format)
function parseStandardQuestions(text) {
    const questions = [];
    const lines = text.split('\n');
    
    let i = 0;
    let skipMode = false; // Skip when we encounter "A B C D" tables
    
    while (i < lines.length) {
        const line = lines[i].trim();
        
        // Check if we hit an "A B C D" table header
        if (line.match(/^A\s+B\s+C\s+D\s*$/)) {
            skipMode = true;
            i++;
            continue;
        }
        
        // Exit skip mode when we see "Read the passage" or a long line
        if (skipMode && (line.includes('Read the passage') || line.length > 100)) {
            skipMode = false;
        }
        
        if (skipMode) {
            i++;
            continue;
        }
        
        // Match question: "21. Question text here..."
        const qMatch = line.match(/^(\d+)\.\s+(.+)/);
        
        if (qMatch && !line.includes('___')) {
            const qNum = parseInt(qMatch[1]);
            let questionText = qMatch[2];
            
            // Continue reading until we hit options
            i++;
            while (i < lines.length && !lines[i].trim().match(/^[A-D]\./)) {
                const nextLine = lines[i].trim();
                if (nextLine && !nextLine.match(/^\d+\./)) {
                    questionText += ' ' + nextLine;
                }
                i++;
            }
            
            // Read options A-D
            const options = [];
            while (i < lines.length && options.length < 4) {
                const optLine = lines[i].trim();
                const optMatch = optLine.match(/^([A-D])\.\s+(.+)/);
                
                if (optMatch) {
                    options.push(`${optMatch[1]}. ${optMatch[2]}`);
                    i++;
                } else {
                    break;
                }
            }
            
            if (options.length === 4) {
                questions.push({
                    questionNumber: qNum,
                    question: questionText.trim(),
                    options
                });
            }
        } else {
            i++;
        }
    }
    
    return questions;
}

// Parse inline format: "11. questionA. opt1B. opt2C. opt3D. opt4"
function parseInlineQuestions(text) {
    const questions = [];
    const lines = text.split('\n');
    
    for (const line of lines) {
        const trimmed = line.trim();
        
        // Match pattern: number, question text, then options starting with A.
        const match = trimmed.match(/^(\d+)\.\s+(.+?)([A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?)$/);
        
        if (match) {
            const qNum = parseInt(match[1]);
            const questionPart = match[2];
            const optionsPart = match[3];
            
            // Parse options by looking for A. B. C. D. markers
            const options = [];
            let currentOption = '';
            let currentLetter = '';
            
            for (let i = 0; i < optionsPart.length; i++) {
                const char = optionsPart[i];
                const next = optionsPart[i + 1];
                
                // Check if this is a letter marker (A., B., C., D.)
                if (char.match(/[A-D]/) && next === '.') {
                    if (currentOption && currentLetter) {
                        options.push(`${currentLetter}. ${currentOption.trim()}`);
                    }
                    currentLetter = char;
                    currentOption = '';
                    i++; // Skip the period
                } else {
                    currentOption += char;
                }
            }
            
            // Push last option
            if (currentOption && currentLetter) {
                options.push(`${currentLetter}. ${currentOption.trim()}`);
            }
            
            if (options.length === 4) {
                questions.push({
                    questionNumber: qNum,
                    question: questionPart.trim(),
                    options
                });
            }
        }
    }
    
    return questions;
}

// Parse inline table format (compact tables with options in rows)
function parseInlineTable(text) {
    const questions = [];
    
    // Find compact tables: "A B C D" followed by numbered rows
    const tableRegex = /A\s+B\s+C\s+D\s*\n?\s*(\d+\.[\s\S]+?)(?=\n\n\n|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    for (const tableMatch of tableMatches) {
        const tableText = tableMatch[1];
        
        // Parse lines like "11. opt1 opt2 opt3 opt4"
        const lines = tableText.split('\n');
        
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            
            const qMatch = trimmed.match(/^(\d+)\.\s+(.+)/);
            if (qMatch) {
                const qNum = parseInt(qMatch[1]);
                const optionsText = qMatch[2];
                
                // Split by whitespace, but handle multi-word French phrases
                const words = optionsText.trim().split(/\s+/);
                const options = [];
                let currentOption = '';
                
                for (const word of words) {
                    // Detect French articles that start multi-word phrases
                    if (currentOption && word.match(/^(le|la|les|un|une|des|l'|de|du|au|aux)\b/i)) {
                        options.push(currentOption.trim());
                        currentOption = word;
                    } else if (currentOption) {
                        currentOption += ' ' + word;
                    } else {
                        currentOption = word;
                    }
                }
                
                if (currentOption) {
                    options.push(currentOption.trim());
                }
                
                // Take first 4 options
                if (options.length >= 4) {
                    const formattedOptions = options.slice(0, 4).map((opt, i) => 
                        `${String.fromCharCode(65 + i)}. ${opt}`
                    );
                    
                    // Find question text from PART II or IV
                    let questionText = '';
                    
                    if (qNum >= 11 && qNum <= 20) {
                        const part2Match = text.match(/PART II.+?(?=PART III|PART IV|$)/s);
                        if (part2Match) {
                            const qTextMatch = part2Match[0].match(new RegExp(`${qNum}\\.\\s+([^.]+?\\.{3,})`));
                            if (qTextMatch) {
                                questionText = qTextMatch[1].trim();
                            }
                        }
                    }
                    
                    if (qNum >= 31 && qNum <= 40) {
                        const blankMatch = text.match(new RegExp(`–\\s*${qNum}\\s*–`));
                        if (blankMatch) {
                            const start = Math.max(0, blankMatch.index - 50);
                            const end = Math.min(text.length, blankMatch.index + 50);
                            const context = text.substring(start, end);
                            questionText = context.replace(new RegExp(`–\\s*${qNum}\\s*–`), '_____').trim();
                        }
                    }
                    
                    questions.push({
                        questionNumber: qNum,
                        question: questionText || `Complete the blank in question ${qNum}`,
                        options: formattedOptions
                    });
                }
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
    
    console.log(`Found question texts for: ${Object.keys(questionTexts).join(', ')}`);
    
    // Find columnar tables: "A.    B.    C.    D." followed by rows
    const tableRegex = /A\.\s+B\.\s+C\.\s+D\.(.+?)(?=PART|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    let tableCount = 0;
    for (const tableMatch of tableMatches) {
        tableCount++;
        const tableText = tableMatch[1];
        console.log(`\nTable ${tableCount} - length: ${tableText.length} chars`);
        
        // Parse rows using the regex pattern
        const rowMatches = tableText.matchAll(/(\d+)\.\s+(.+?)(?=\d+\.|$)/gs);
        
        let rowCount = 0;
        for (const rowMatch of rowMatches) {
            rowCount++;
            const qNum = parseInt(rowMatch[1]);
            const optionsLine = rowMatch[2];
            
            // Split by multiple spaces (columns are separated by whitespace)
            const parts = optionsLine.split(/\s{2,}/).filter(p => p.trim());
            
            console.log(`  Row ${rowCount} Q${qNum}: ${parts.length} parts`);
            
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
        
        console.log(`  Found ${rowCount} rows in table ${tableCount}`);
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

// Import questions for specific years
async function importYears() {
    const years = ['2015', '2016'];
    
    // Parse answer key first
    console.log('Parsing French answer key...');
    const answers = await parseFrenchAnswers();
    
    for (const year of years) {
        console.log(`\nProcessing year ${year}...`);
        
        const filePath = `assets/bece french/bece  french ${year}  questions.docx`;
        
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
        
        // Special case: Add Q26 for 2015 (inline format on separate line)
        if (year === '2015' && !questions.find(q => q.questionNumber === 26)) {
            console.log('Adding special case Q26 for 2015...');
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
