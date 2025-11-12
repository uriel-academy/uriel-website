const ss = require('./assets/bece_json/bece_social_studies_questions.json');
const is = require('./assets/bece_json/bece_integrated_science_questions.json');

console.log('📊 Social Studies - Years with <40 questions:');
const ssByYear = {};
ss.forEach(q => { ssByYear[q.year] = (ssByYear[q.year] || 0) + 1; });
Object.keys(ssByYear).sort().forEach(y => { 
  if (ssByYear[y] < 40) console.log(`   ${y}: ${ssByYear[y]} questions (missing ${40 - ssByYear[y]})`); 
});

console.log('\n📊 Integrated Science - Years with <40 questions:');
const isByYear = {};
is.forEach(q => { isByYear[q.year] = (isByYear[q.year] || 0) + 1; });
Object.keys(isByYear).sort().forEach(y => { 
  if (isByYear[y] < 40) console.log(`   ${y}: ${isByYear[y]} questions (missing ${40 - isByYear[y]})`); 
});

console.log('\n📈 Summary:');
console.log(`   Social Studies: ${Object.keys(ssByYear).filter(y => ssByYear[y] < 40).length} years incomplete`);
console.log(`   Integrated Science: ${Object.keys(isByYear).filter(y => isByYear[y] < 40).length} years incomplete`);
