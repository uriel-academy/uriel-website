const mammoth = require('mammoth');

// Parse inline format questions (2012-2016 style)
function parseInlineQuestions(text) {
    const questions = [];
    
    // Split by question numbers
    const lines = text.split('\n');
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;
        
        // Match: "NUMBER. question text...A. optionB. optionC. optionD. option"
        const match = line.match(/^(\d+)\.\s+(.+?)([A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?[A-D]\.\s*.+?)$/);
        
        if (match) {
            const questionNumber = parseInt(match[1]);
            const questionText = match[2].trim();
            const optionsText = match[3];
            
            // Extract options from inline format
            // Pattern: A. textB. textC. textD. text
            const optionMatches = optionsText.match(/([A-D])\.\s*([^A-D]+?)(?=[A-D]\.|$)/g);
            
            if (optionMatches && optionMatches.length === 4) {
                const options = optionMatches.map(opt => {
                    const [letter, ...textParts] = opt.split('.');
                    return `${letter}. ${textParts.join('.').trim()}`;
                });
                
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

async function test() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const text = result.value;
    console.log('Text length:', text.length);
    
    const questions = parseInlineQuestions(text);
    console.log('\nFound', questions.length, 'questions\n');
    
    questions.slice(0, 5).forEach(q => {
        console.log(`Q${q.questionNumber}: ${q.question.substring(0, 50)}...`);
        console.log('Options:', q.options.length);
        q.options.forEach(opt => console.log('  ', opt.substring(0, 40)));
        console.log();
    });
}

test();
