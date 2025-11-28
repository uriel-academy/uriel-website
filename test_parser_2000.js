const mammoth = require('mammoth');

async function testParser() {
    const filePath = 'assets/bece french/bece  french 2000 questions.docx';
    const result = await mammoth.extractRawText({ path: filePath });
    const text = result.value;
    const lines = text.split('\n');
    
    const questions = [];
    let currentQuestion = null;
    let currentOptions = [];
    
    for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        
        // Question number
        const questionMatch = trimmed.match(/^(\d+)\.\s+(.+)/);
        if (questionMatch) {
            // Save previous question
            if (currentQuestion && currentOptions.length === 4) {
                questions.push({
                    number: currentQuestion.number,
                    question: currentQuestion.text,
                    options: currentOptions
                });
            }
            
            // Start new question
            currentQuestion = {
                number: parseInt(questionMatch[1]),
                text: questionMatch[2]
            };
            currentOptions = [];
            continue;
        }
        
        // Option line
        const optionMatch = trimmed.match(/^([A-D])\.?\s*(.*)$/);
        if (optionMatch && currentQuestion) {
            const optText = optionMatch[2].trim();
            // Skip if option text is empty (might be on next line)
            if (optText) {
                currentOptions.push(`${optionMatch[1]}. ${optText}`);
                
                // If we have all 4 options, save
                if (currentOptions.length === 4) {
                    questions.push({
                        number: currentQuestion.number,
                        question: currentQuestion.text,
                        options: currentOptions
                    });
                    currentQuestion = null;
                    currentOptions = [];
                }
            }
        }
    }
    
    console.log(`Parsed ${questions.length} questions`);
    console.log('\nFirst 3:');
    questions.slice(0, 3).forEach(q => {
        console.log(`Q${q.number}: ${q.question}`);
        q.options.forEach(o => console.log(`  ${o}`));
    });
    
    console.log('\nLast 3:');
    questions.slice(-3).forEach(q => {
        console.log(`Q${q.number}: ${q.question}`);
        q.options.forEach(o => console.log(`  ${o}`));
    });
    
    console.log(`\nQuestion numbers: ${questions.map(q => q.number).join(', ')}`);
}

testParser();
