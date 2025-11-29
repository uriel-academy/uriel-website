const admin = require('firebase-admin');

// Initialize Firebase Admin using default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'uriel-academy-41fb0',
  });
}

const db = admin.firestore();

const sampleStorybooks = [
  {
    id: 'anansi_and_wisdom',
    title: 'Anansi and the Pot of Wisdom',
    author: 'Traditional Ghanaian Folktale',
    category: 'Folktales',
    ageRange: '8-12',
    language: 'English',
    description: 'A classic Ghanaian folktale about Anansi the spider who tries to keep all the world\'s wisdom for himself.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Fanansi_wisdom.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Fanansi_wisdom.pdf?alt=media',
    epubUrl: '',
    fileSize: 2.5,
    pageCount: 24,
    rating: 4.8,
    downloadCount: 1250,
    viewCount: 3400,
    isActive: true,
    isFeatured: true,
    tags: ['folklore', 'wisdom', 'animals', 'traditional'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'the_clever_tortoise',
    title: 'The Clever Tortoise',
    author: 'Traditional African Story',
    category: 'Folktales',
    ageRange: '6-10',
    language: 'English',
    description: 'An entertaining story about how the slow but clever tortoise outwits the faster animals in the forest.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Ftortoise.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Ftortoise.pdf?alt=media',
    epubUrl: '',
    fileSize: 1.8,
    pageCount: 16,
    rating: 4.6,
    downloadCount: 980,
    viewCount: 2100,
    isActive: true,
    isFeatured: false,
    tags: ['animals', 'wisdom', 'cleverness', 'traditional'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'kofi_and_the_drum',
    title: 'Kofi and the Magic Drum',
    author: 'Ama Ata Aidoo',
    category: 'Adventure',
    ageRange: '8-12',
    language: 'English',
    description: 'Young Kofi discovers a magic drum that brings good fortune to his village when played with kindness.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Fkofi_drum.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Fkofi_drum.pdf?alt=media',
    epubUrl: '',
    fileSize: 3.2,
    pageCount: 32,
    rating: 4.9,
    downloadCount: 1500,
    viewCount: 4200,
    isActive: true,
    isFeatured: true,
    tags: ['adventure', 'magic', 'kindness', 'village life'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'the_golden_stool',
    title: 'The Legend of the Golden Stool',
    author: 'Kwame Nkrumah',
    category: 'History',
    ageRange: '10-14',
    language: 'English',
    description: 'The fascinating story of the Asante Golden Stool and its significance in Ghanaian history and culture.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Fgolden_stool.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Fgolden_stool.pdf?alt=media',
    epubUrl: '',
    fileSize: 4.1,
    pageCount: 40,
    rating: 4.7,
    downloadCount: 850,
    viewCount: 2800,
    isActive: true,
    isFeatured: true,
    tags: ['history', 'asante', 'culture', 'tradition'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'amina_scientist',
    title: 'Amina the Young Scientist',
    author: 'Dr. Nana Adjei',
    category: 'Educational',
    ageRange: '8-12',
    language: 'English',
    description: 'Follow Amina as she uses science to solve problems in her community and inspire other young girls.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Famina_scientist.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Famina_scientist.pdf?alt=media',
    epubUrl: '',
    fileSize: 2.9,
    pageCount: 28,
    rating: 4.8,
    downloadCount: 1100,
    viewCount: 3200,
    isActive: true,
    isFeatured: true,
    tags: ['science', 'education', 'girls', 'inspiration'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'river_adventure',
    title: 'Adventures on the Volta River',
    author: 'Yaa Gyasi',
    category: 'Adventure',
    ageRange: '10-14',
    language: 'English',
    description: 'Three friends embark on an exciting journey down the Volta River, learning about Ghana\'s geography and wildlife.',
    coverUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybook_covers%2Fvolta_adventure.jpg?alt=media',
    pdfUrl: 'https://firebasestorage.googleapis.com/v0/b/uriel-academy-41fb0.appspot.com/o/storybooks%2Fvolta_adventure.pdf?alt=media',
    epubUrl: '',
    fileSize: 3.5,
    pageCount: 36,
    rating: 4.7,
    downloadCount: 920,
    viewCount: 2600,
    isActive: true,
    isFeatured: false,
    tags: ['adventure', 'geography', 'friendship', 'nature'],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

async function addStorybooks() {
  console.log('📚 Adding sample storybooks to Firestore...\n');

  try {
    for (const storybook of sampleStorybooks) {
      await db.collection('storybooks').doc(storybook.id).set(storybook);
      console.log(`✅ Added: ${storybook.title}`);
    }

    console.log(`\n✨ Successfully added ${sampleStorybooks.length} storybooks!`);
    console.log('\n📊 Summary:');
    console.log(`   - Folktales: ${sampleStorybooks.filter(b => b.category === 'Folktales').length}`);
    console.log(`   - Adventure: ${sampleStorybooks.filter(b => b.category === 'Adventure').length}`);
    console.log(`   - History: ${sampleStorybooks.filter(b => b.category === 'History').length}`);
    console.log(`   - Educational: ${sampleStorybooks.filter(b => b.category === 'Educational').length}`);
    console.log(`   - Featured: ${sampleStorybooks.filter(b => b.isFeatured).length}`);

  } catch (error) {
    console.error('❌ Error adding storybooks:', error);
  } finally {
    process.exit(0);
  }
}

addStorybooks();
