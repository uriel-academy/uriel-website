const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Manual fixes for problematic titles
const manualFixes = {
  'candide-voltaire': { title: 'Candide', author: 'Voltaire' },
  'dialogues-plato': { title: 'Dialogues', author: 'Plato' },
  'dubliners-james-joyce': { title: 'Dubliners', author: 'James Joyce' },
  'fables-aesop': { title: 'Fables', author: 'Aesop' },
  'frankenstein-mary-shelley': { title: 'Frankenstein', author: 'Mary Shelley' },
  'leviathan-thomas-hobbes': { title: 'Leviathan', author: 'Thomas Hobbes' },
  'middlemarch-george-eliot': { title: 'Middlemarch', author: 'George Eliot' },
  'alices-adventures-in-wonderland-lewis-carroll': { title: 'Alice\'s Adventures in Wonderland', author: 'Lewis Carroll' },
  'beowulf-an-anglo-saxon-epic-poem': { title: 'Beowulf: An Anglo-Saxon Epic Poem', author: 'Unknown' },
  'pride-prejudice-jane-austen': { title: 'Pride and Prejudice', author: 'Jane Austen' },
  'sense-and-sensibility-jane-austen': { title: 'Sense and Sensibility', author: 'Jane Austen' },
  'emma-jane-austen': { title: 'Emma', author: 'Jane Austen' },
  'crime-and-punishment-fyodor-dostoevsky': { title: 'Crime and Punishment', author: 'Fyodor Dostoevsky' },
  'dracula-bram-stoker': { title: 'Dracula', author: 'Bram Stoker' },
  'moby-dick-herman-melville': { title: 'Moby Dick', author: 'Herman Melville' },
  'les-miserables-victor-hugo': { title: 'Les Misérables', author: 'Victor Hugo' },
  'the-iliad-homer': { title: 'The Iliad', author: 'Homer' },
  'the-odyssey-homer': { title: 'The Odyssey', author: 'Homer' },
  'thus-spake-zarathustra-friedrich-nietzsche': { title: 'Thus Spoke Zarathustra', author: 'Friedrich Nietzsche' },
  'cup-of-gold-john-steinbeck': { title: 'Cup of Gold', author: 'John Steinbeck' },
  'flatland-edwin-a-abbott': { title: 'Flatland', author: 'Edwin A. Abbott' },
  'little-women-louisa-may-alcott': { title: 'Little Women', author: 'Louisa May Alcott' },
  'on-liberty-john-stuart-mill': { title: 'On Liberty', author: 'John Stuart Mill' },
  'paradise-lost-john-milton': { title: 'Paradise Lost', author: 'John Milton' },
  'philosophical-works-rene-descartes': { title: 'Philosophical Works', author: 'René Descartes' },
  'poetry-edgar-allan-poe': { title: 'Poetry', author: 'Edgar Allan Poe' },
  'walden-henry-david-thoreau': { title: 'Walden', author: 'Henry David Thoreau' },
  'women-and-economics-charlotte-perkins-gilman': { title: 'Women and Economics', author: 'Charlotte Perkins Gilman' },
  'the-scarlet-letter-nathaniel-hawthorne': { title: 'The Scarlet Letter', author: 'Nathaniel Hawthorne' },
  'in-a-glass-darkly-joseph-sheridan-le-fanu': { title: 'In a Glass Darkly', author: 'Joseph Sheridan Le Fanu' },
  'in-search-of-lost-time-marcel-proust': { title: 'In Search of Lost Time', author: 'Marcel Proust' },
  'le-morte-d-arthur-sir-thomas-malory': { title: 'Le Morte d\'Arthur', author: 'Sir Thomas Malory' },
  'the-importance-of-being-earnest-oscar-wilde': { title: 'The Importance of Being Earnest', author: 'Oscar Wilde' },
  'the-picture-of-dorian-gray-oscar-wilde': { title: 'The Picture of Dorian Gray', author: 'Oscar Wilde' },
  'tractatus-logico-philosophicus-ludwig-wittgenstein': { title: 'Tractatus Logico-Philosophicus', author: 'Ludwig Wittgenstein' },
};

async function fixStorybookTitles() {
  console.log('🔧 Fixing Storybook Titles...\n');
  
  let fixedCount = 0;
  let errorCount = 0;
  
  for (const [id, fixes] of Object.entries(manualFixes)) {
    try {
      const docRef = db.collection('storybooks').doc(id);
      const doc = await docRef.get();
      
      if (doc.exists) {
        await docRef.update({
          title: fixes.title,
          author: fixes.author,
        });
        console.log(`✅ Fixed: "${fixes.title}" by ${fixes.author}`);
        fixedCount++;
      } else {
        console.log(`⏭️  Skipped: ${id} (not found)`);
      }
    } catch (error) {
      console.error(`❌ Error fixing ${id}:`, error.message);
      errorCount++;
    }
  }
  
  console.log('\n' + '='.repeat(80));
  console.log(`📊 Fix Summary:`);
  console.log(`   ✅ Fixed: ${fixedCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log('='.repeat(80));
  console.log('✨ Fix Complete!');
  
  process.exit(0);
}

// Run fixes
fixStorybookTitles();
