const mammoth = require('mammoth');

async function test2010() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2010  questions.docx'
    });
    
    const text = result.value;
    const questions = parseStandardQuestions(text);
    
    console.log('Found', questions.length, 'standard questions:');
    questions.forEach(q => {
        console.log(`Q${q.questionNumber}: ${q.options.length} options`);
    });
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
            console.log('  [Skip mode ON at line', i, ']');
            skipMode = true;
            continue;
        }
        
        if (skipMode && (/^Read the passage/i.test(trimmed) || /^For each question/i.test(trimmed) || trimmed.length > 80)) {
            console.log('  [Skip mode OFF at line', i, ']');
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

test2010();
