const mammoth = require('mammoth');

// Copy the parseInlineTable function
function parseInlineTable(text) {
    const questions = [];
    
    const questionTexts = {};
    
    const part2Match = text.match(/PART II.+?(?=A\s+B\s+C\s+D)/s);
    if (part2Match) {
        const part2Text = part2Match[0];
        const matches = part2Text.matchAll(/(\d+)\.\s+([^.]+?\.{3,})/g);
        for (const match of matches) {
            const qNum = parseInt(match[1]);
            questionTexts[qNum] = match[2].trim();
        }
    }
    
    const tableRegex = /A\s+B\s+C\s+D\s*\n\s*(.+?)(?=PART|Read the passage|$)/gs;
    const tableMatches = text.matchAll(tableRegex);
    
    for (const tableMatch of tableMatches) {
        const tableText = tableMatch[1];
        console.log('=== TABLE TEXT ===');
        console.log(tableText.substring(0, 300));
        console.log('\n');
        
        const questionRegex = /(\d+)\.\s*([^\d]+?)(?=\d+\.|$)/g;
        const questionMatches = tableText.matchAll(questionRegex);
        
        for (const qMatch of questionMatches) {
            const qNum = parseInt(qMatch[1]);
            const optionsText = qMatch[2].trim();
            
            const words = optionsText.split(/\s+/).filter(p => p && p.length > 0);
            
            let options = [];
            
            if (words.length === 4) {
                options = words.map((w, i) => `${String.fromCharCode(65 + i)}. ${w}`);
            }
            else if (words.length > 4) {
                const articleMarkers = ['la', 'le', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux'];
                const optionGroups = [];
                let currentOption = [];
                
                for (let i = 0; i < words.length; i++) {
                    const word = words[i];
                    const isArticle = articleMarkers.includes(word.toLowerCase()) || word.toLowerCase().startsWith("l'");
                    
                    if (isArticle && currentOption.length > 0 && optionGroups.length < 3) {
                        optionGroups.push(currentOption.join(' '));
                        currentOption = [word];
                    } else {
                        currentOption.push(word);
                    }
                }
                
                if (currentOption.length > 0) {
                    optionGroups.push(currentOption.join(' '));
                }
                
                if (optionGroups.length === 4) {
                    options = optionGroups.map((opt, i) => `${String.fromCharCode(65 + i)}. ${opt}`);
                } else {
                    options = words.slice(0, 4).map((w, i) => `${String.fromCharCode(65 + i)}. ${w}`);
                }
            }
            
            if (options.length === 4) {
                const questionText = questionTexts[qNum] || `Complete the blank in question ${qNum}`;
                
                questions.push({
                    questionNumber: qNum,
                    question: questionText,
                    options
                });
                
                console.log(`Q${qNum}: ${options.length} options`);
            } else {
                console.log(`Q${qNum}: SKIPPED (${options.length} options)`);
            }
        }
    }
    
    return questions;
}

async function test() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const questions = parseInlineTable(result.value);
    console.log('\n=== SUMMARY ===');
    console.log('Found', questions.length, 'questions from table');
}

test();
