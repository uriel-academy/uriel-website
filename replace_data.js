const fs = require('fs');

// Read the data and function content
const data = JSON.parse(fs.readFileSync('ict_questions_data.json', 'utf8'));
const functionContent = fs.readFileSync('functions/src/index.ts', 'utf8');

// Find the embedded data array and replace it
const startMarker = '    // ICT Questions Data (2011-2022 BECE) - Embedded directly in function';
const endMarker = '    ];';

const startIndex = functionContent.indexOf(startMarker);
const endIndex = functionContent.indexOf(endMarker, startIndex) + endMarker.length;

const before = functionContent.substring(0, startIndex + startMarker.length);
const after = functionContent.substring(endIndex);

const newData = JSON.stringify(data, null, 4).split('\n').map(line => '    ' + line).join('\n');

const newContent = before + '\n' + newData + '\n' + after;

fs.writeFileSync('functions/src/index.ts', newContent);
console.log('Replaced embedded data with complete ICT questions data');