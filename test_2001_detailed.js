const mammoth = require('mammoth');

async function testParse2001() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2001 questions.docx'
    });
    
    const text = result.value;
    console.log('=== FULL TEXT LENGTH ===', text.length);
    
    // Test cloze parser
    console.log('\n=== CLOZE QUESTIONS ===');
    const clozeQuestions = parseClozekQuestions(text);
    console.log('Found', clozeQuestions.length, 'cloze questions');
    clozeQuestions.forEach(q => {
        console.log(`Q${q.questionNumber}: ${q.question.substring(0, 50)}...`);
    });
    
    // Test standard parser
    console.log('\n=== STANDARD QUESTIONS ===');
    const standardQuestions = parseStandardQuestions(text);
    console.log('Found', standardQuestions.length, 'standard questions');
    standardQuestions.forEach(q => {
        console.log(`Q${q.questionNumber}: ${q.question.substring(0, 50)}...`);
    });
    
    console.log('\n=== TOTAL ===', clozeQuestions.length + standardQuestions.length);
}

function parseClozekQuestions(text) {
    const questions = [];
    
    if (!/The passage below has.*?numbered spaces/i.test(text)) {
        return questions;
    }
    
    const tableMatch = text.match(/A\s+B\s+C\s+D\s*\n([\s\S]*?)(?=\n\s*11\.|$)/);
    if (!tableMatch) return questions;
    
    const tableText = tableMatch[1];
    const tableLines = tableText.split('\n').filter(l => l.trim());
    
    let foundQuestions = 0;
    
    for (const line of tableLines) {
        const trimmed = line.trim();
        
        if (trimmed === 'A B C D' || !trimmed) continue;
        
        if (foundQuestions >= 10) break;
        
        const parts = trimmed.split(/\s+/);
        if (parts.length >= 5) {
            const firstPart = parts[0].replace('.', '');
            if (/^\d+$/.test(firstPart)) {
                const questionNumber = parseInt(firstPart);
                
                if (questionNumber < 1 || questionNumber > 10) continue;
                
                foundQuestions++;
                
                const options = [
                    `A. ${parts[1]}`,
                    `B. ${parts[2]}`,
                    `C. ${parts[3]}`,
                    `D. ${parts[4]}`
                ];
                
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

function parseStandardQuestions(text) {
    const questions = [];
    const lines = text.split('\n');
    
    let currentQuestion = null;
    let currentOptions = [];
    let skipMode = false;
    
    for (let i = 0; i < lines.length; i++) {
        const trimmed = lines[i].trim();
        
        if (trimmed === 'A B C D') {
            skipMode = true;
            continue;
        }
        
        if (skipMode && (/^Read the passage/i.test(trimmed) || /^For each question/i.test(trimmed) || trimmed.length > 80)) {
            skipMode = false;
        }
        
        if (skipMode) continue;
        
        if (!trimmed) continue;
        
        const questionMatch = trimmed.match(/^(\d+)\.\s+(.+)/);
        if (questionMatch) {
            const qNum = parseInt(questionMatch[1]);
            
            if (currentQuestion && currentOptions.length === 4) {
                questions.push({
                    questionNumber: currentQuestion.number,
                    question: currentQuestion.text,
                    options: currentOptions
                });
            }
            
            currentQuestion = {
                number: qNum,
                text: questionMatch[2]
            };
            currentOptions = [];
            continue;
        }
        
        const optionMatch = trimmed.match(/^([A-D])\.?\s*(.*)$/);
        if (optionMatch && currentQuestion) {
            const optText = optionMatch[2].trim();
            if (optText) {
                currentOptions.push(`${optionMatch[1]}. ${optText}`);
                
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

testParse2001();
