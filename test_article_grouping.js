const optionsText = "la bibliothèque la librairie l'église l'hôtel";
const words = optionsText.split(/\s+/).filter(p => p && p.length > 0);

console.log('Words:', words);
console.log('Count:', words.length);

const articleMarkers = ['la', 'le', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux'];
const optionGroups = [];
let currentOption = [];

for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const isArticle = articleMarkers.includes(word.toLowerCase()) || word.toLowerCase().startsWith("l'");
    
    console.log(`Word "${word}" - isArticle: ${isArticle}, currentOption:`, currentOption);
    
    // Start a new option if we hit an article and already have words
    if (isArticle && currentOption.length > 0 && optionGroups.length < 3) {
        console.log('  -> Pushing group:', currentOption.join(' '));
        optionGroups.push(currentOption.join(' '));
        currentOption = [word];
    } else {
        currentOption.push(word);
    }
}

// Add final option
if (currentOption.length > 0) {
    console.log('Final group:', currentOption.join(' '));
    optionGroups.push(currentOption.join(' '));
}

console.log('\nFinal groups:', optionGroups);
