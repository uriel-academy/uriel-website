const mammoth = require('mammoth');

async function test2012() {
    const result = await mammoth.extractRawText({
        path: 'assets/bece french/bece  french 2012  questions.docx'
    });
    
    const text = result.value;
    
    // Find PART II section
    const part2Match = text.match(/PART II(.+?)PART III/s);
    if (part2Match) {
        console.log('=== PART II (Q11-Q20) ===');
        console.log(part2Match[1].substring(0, 500));
    }
    
    // Find the table after PART II
    const tableMatch = text.match(/A\s+B\s+C\s+D\s*11\..+?(?=PART|$)/s);
    if (tableMatch) {
        console.log('\n=== TABLE FORMAT ===');
        console.log(tableMatch[0].substring(0, 500));
    }
    
    // Find PART IV (cloze)
    const part4Match = text.match(/PART IV(.+?)$/s);
    if (part4Match) {
        console.log('\n=== PART IV (Q31-Q40) ===');
        console.log(part4Match[1].substring(0, 600));
    }
}

test2012();
