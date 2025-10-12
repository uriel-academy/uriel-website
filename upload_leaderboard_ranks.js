/**
 * Upload Leaderboard Rank Images and Metadata to Firebase
 * 
 * This script:
 * 1. Uploads all rank images from assets/leaderboards_rank to Firebase Storage
 * 2. Creates Firestore documents with rank metadata (name, XP range, description, theme, tier)
 * 3. Links the storage URLs to the Firestore documents
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'uriel-academy-41fb0.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Complete Rank Metadata
const RANK_DATA = [
  // BEGINNER TIER (1-5)
  {
    rank: 1,
    name: 'Learner',
    minXP: 0,
    maxXP: 999,
    tier: 'Beginner',
    tierTheme: 'Discovery & Curiosity',
    description: "You've just opened the door. Every click, every question, every note is a step forward.",
    meaning: 'Every great learner starts with a single question.',
    psychology: 'Quick wins to spark motivation and show early progress.',
    color: '#4CAF50',
    colorTheme: 'Soft green hues symbolizing growth and new beginnings'
  },
  {
    rank: 2,
    name: 'Explorer',
    minXP: 1000,
    maxXP: 4999,
    tier: 'Beginner',
    tierTheme: 'Discovery & Curiosity',
    description: "You're wandering through new subjects and discovering your rhythm.",
    achievements: 'Completed first quizzes, explored textbooks, maintained first streak.',
    psychology: 'Encourages curiosity and experimentation.',
    color: '#66BB6A',
    visualTheme: 'Map icons, compass motifs'
  },
  {
    rank: 3,
    name: 'Scholar',
    minXP: 5000,
    maxXP: 9999,
    tier: 'Beginner',
    tierTheme: 'Discovery & Curiosity',
    description: "You're now building discipline. Learning feels less like effort and more like discovery.",
    achievements: 'Multiple quizzes completed, improved accuracy.',
    psychology: 'Reinforces mastery through visible improvement.',
    color: '#81C784',
    visualTheme: 'Scrolls, books, academic robes'
  },
  {
    rank: 4,
    name: 'Thinker',
    minXP: 10000,
    maxXP: 14999,
    tier: 'Beginner',
    tierTheme: 'Discovery & Curiosity',
    description: 'You pause to understand why, not just what.',
    achievements: 'Started using AI tools, deeper reflection sessions.',
    psychology: 'Encourages higher-order thinking and curiosity.',
    color: '#26A69A',
    visualTheme: 'Mind-light motifs, abstract icons'
  },
  {
    rank: 5,
    name: 'Strategist',
    minXP: 15000,
    maxXP: 19999,
    tier: 'Beginner',
    tierTheme: 'Discovery & Curiosity',
    description: 'You plan study sessions with intention.',
    achievements: 'Built study streaks, used revision plans, managed time well.',
    psychology: 'Shifts mindset from "try" to "train."',
    color: '#00897B',
    visualTheme: 'Chess pieces, blueprint patterns'
  },
  
  // ACHIEVER TIER (6-10)
  {
    rank: 6,
    name: 'Achiever',
    minXP: 20000,
    maxXP: 24999,
    tier: 'Achiever',
    tierTheme: 'Consistency & Growth',
    description: "You've proven consistency.",
    achievements: 'Completed subject modules, top quiz performances.',
    psychology: 'Triggers pride and identity with progress.',
    color: '#FFB300',
    visualTheme: 'Gold medal glow'
  },
  {
    rank: 7,
    name: 'Visionary',
    minXP: 25000,
    maxXP: 29999,
    tier: 'Achiever',
    tierTheme: 'Consistency & Growth',
    description: "You're seeing beyond scores — focusing on purpose.",
    achievements: 'Engaged with notes, motivated peers.',
    psychology: 'Encourages meaningful learning, not rote.',
    color: '#FFA726',
    visualTheme: 'Eye and horizon motifs'
  },
  {
    rank: 8,
    name: 'Trail Seeker',
    minXP: 30000,
    maxXP: 34999,
    tier: 'Achiever',
    tierTheme: 'Consistency & Growth',
    description: "You're blazing your own learning path.",
    achievements: 'Mixed-subject quizzes, AI-assisted exploration.',
    psychology: 'Keeps users in discovery flow.',
    color: '#FF9800',
    visualTheme: 'Path icons, maps, light trails'
  },
  {
    rank: 9,
    name: 'Guide',
    minXP: 35000,
    maxXP: 39999,
    tier: 'Achiever',
    tierTheme: 'Consistency & Growth',
    description: 'You help others find their way.',
    achievements: 'Shared notes, top leaderboard appearances.',
    psychology: 'Introduces social value — teaching reinforces mastery.',
    color: '#FB8C00',
    visualTheme: 'Lanterns, guiding stars'
  },
  {
    rank: 10,
    name: 'Mentor',
    minXP: 40000,
    maxXP: 44999,
    tier: 'Achiever',
    tierTheme: 'Consistency & Growth',
    description: "You've evolved from learner to leader.",
    achievements: 'Peer recognition, consistent excellence.',
    psychology: 'Rewards altruism and contribution.',
    color: '#F57C00',
    visualTheme: 'Light hands, open book with halo'
  },
  
  // ADVANCED TIER (11-15)
  {
    rank: 11,
    name: 'Prodigy',
    minXP: 45000,
    maxXP: 49999,
    tier: 'Advanced',
    tierTheme: 'Mastery & Leadership',
    description: 'You stand out for brilliance and accuracy.',
    achievements: 'Multiple top-scoring sessions, badges earned.',
    psychology: 'Sparks competitive motivation.',
    color: '#5E35B1',
    visualTheme: 'Sparkling star motifs'
  },
  {
    rank: 12,
    name: 'Luminary',
    minXP: 50000,
    maxXP: 54999,
    tier: 'Advanced',
    tierTheme: 'Mastery & Leadership',
    description: 'You shine bright in your academic community.',
    achievements: 'Consistent top ranks, peer influence.',
    psychology: 'Social recognition through visibility.',
    color: '#673AB7',
    visualTheme: 'Radiant sunburst or glowing lamp'
  },
  {
    rank: 13,
    name: 'Innovator',
    minXP: 55000,
    maxXP: 59999,
    tier: 'Advanced',
    tierTheme: 'Mastery & Leadership',
    description: 'You experiment with new study methods and tech tools.',
    achievements: 'AI plan completions, cross-disciplinary success.',
    psychology: 'Rewards creativity and initiative.',
    color: '#7E57C2',
    visualTheme: 'Gear + light bulb fusion'
  },
  {
    rank: 14,
    name: 'Vanguard',
    minXP: 60000,
    maxXP: 64999,
    tier: 'Advanced',
    tierTheme: 'Mastery & Leadership',
    description: 'You lead the frontier of learning on Uriel.',
    achievements: 'Early adoption of new features, community engagement.',
    psychology: 'Establishes elite identity.',
    color: '#9575CD',
    visualTheme: 'Shield or forward-moving arrow'
  },
  {
    rank: 15,
    name: 'Champion',
    minXP: 65000,
    maxXP: 69999,
    tier: 'Advanced',
    tierTheme: 'Mastery & Leadership',
    description: "You've conquered challenges that once felt impossible.",
    achievements: 'Finished entire subject categories.',
    psychology: 'Gratifying competence recognition.',
    color: '#B39DDB',
    visualTheme: 'Trophy, golden laurel'
  },
  
  // EXPERT TIER (16-21)
  {
    rank: 16,
    name: 'Pathfinder',
    minXP: 70000,
    maxXP: 74999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: 'You chart new approaches to learning.',
    achievements: 'Exploration of underused subjects, community notes.',
    psychology: 'Rewards creativity and leadership.',
    color: '#1976D2',
    visualTheme: 'Compass-arrow motif'
  },
  {
    rank: 17,
    name: 'Mastermind',
    minXP: 75000,
    maxXP: 79999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: 'You combine logic, insight, and strategy.',
    achievements: 'Exceptional performance in analytical subjects.',
    psychology: 'Celebrates intellectual depth.',
    color: '#2196F3',
    visualTheme: 'Brain + circuit pattern'
  },
  {
    rank: 18,
    name: 'Elite',
    minXP: 80000,
    maxXP: 84999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: "You've achieved what few have.",
    achievements: 'Multiple months of streaks, advanced quiz tiers.',
    psychology: 'Recognition of rarity — scarcity effect.',
    color: '#42A5F5',
    visualTheme: 'Platinum glow or metallic crown'
  },
  {
    rank: 19,
    name: 'Sage',
    minXP: 85000,
    maxXP: 89999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: 'Wisdom now guides your learning.',
    achievements: 'Balanced excellence across subjects.',
    psychology: 'Promotes humility through wisdom.',
    color: '#64B5F6',
    visualTheme: 'Ancient scroll, tree of knowledge'
  },
  {
    rank: 20,
    name: 'Legend',
    minXP: 90000,
    maxXP: 94999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: "You've become a story within the Uriel community.",
    achievements: 'Continuous leadership and top-3 leaderboard spots.',
    psychology: 'Inspires others — fame through merit.',
    color: '#90CAF9',
    visualTheme: 'Laurel crown, glowing emblem'
  },
  {
    rank: 21,
    name: 'Trailblazer',
    minXP: 95000,
    maxXP: 99999,
    tier: 'Expert',
    tierTheme: 'Dedication & Excellence',
    description: "You embody Uriel's creed — Learn. Practice. Succeed.",
    achievements: 'Full platform mastery.',
    psychology: 'Capstone identity before elite tiers.',
    color: '#BBDEFB',
    visualTheme: 'Meteor trail or torch flame'
  },
  
  // PRESTIGE TIER (22-25)
  {
    rank: 22,
    name: 'Grand Scholar',
    minXP: 100000,
    maxXP: 109999,
    tier: 'Prestige',
    tierTheme: 'Legacy & Mastery',
    description: "You've mastered multiple subjects.",
    achievements: 'Broad-based distinction.',
    psychology: 'Rewards diversity of excellence.',
    color: '#E1BEE7',
    visualTheme: 'Multi-book crest'
  },
  {
    rank: 23,
    name: 'Virtuoso',
    minXP: 110000,
    maxXP: 124999,
    tier: 'Prestige',
    tierTheme: 'Legacy & Mastery',
    description: 'You perform learning like an art form.',
    achievements: 'Top percentile across tests.',
    psychology: 'Fuses intellect with creative pride.',
    color: '#CE93D8',
    visualTheme: 'Quill + wave pattern'
  },
  {
    rank: 24,
    name: 'Epic',
    minXP: 125000,
    maxXP: 149999,
    tier: 'Prestige',
    tierTheme: 'Legacy & Mastery',
    description: 'Your journey itself is a legend.',
    achievements: 'Sustained mastery and community respect.',
    psychology: 'Immortalizes long-term effort.',
    color: '#BA68C8',
    visualTheme: 'Sword through light beam'
  },
  {
    rank: 25,
    name: 'Mythic',
    minXP: 150000,
    maxXP: 199999,
    tier: 'Prestige',
    tierTheme: 'Legacy & Mastery',
    description: 'A rank reserved for icons of persistence.',
    achievements: 'Year-long streaks, perfect scores, or community awards.',
    psychology: 'Exclusive recognition tier.',
    color: '#AB47BC',
    visualTheme: 'Ancient seal, divine glow'
  },
  
  // SUPREME TIER (26-28)
  {
    rank: 26,
    name: 'Urielian',
    minXP: 200000,
    maxXP: 299999,
    tier: 'Supreme',
    tierTheme: 'Enlightenment & Legacy',
    description: "You are one with Uriel's mission — embodying wisdom, consistency, and discipline.",
    achievements: 'Long-term streaks, leadership roles, community mentorship.',
    psychology: 'Represents brand embodiment; aspirational title.',
    color: '#3F51B5',
    visualTheme: 'Diamond-blue glow, book with radiant wings'
  },
  {
    rank: 27,
    name: 'Ascendant',
    minXP: 300000,
    maxXP: 499999,
    tier: 'Supreme',
    tierTheme: 'Enlightenment & Legacy',
    description: "You've transcended ordinary study — learning is now your lifestyle.",
    achievements: 'Continuous top 1% ranking.',
    psychology: 'Symbolizes mastery beyond competition.',
    color: '#5C6BC0',
    visualTheme: 'Ethereal gradient, upward motion light pattern'
  },
  {
    rank: 28,
    name: 'The Enlightened',
    minXP: 500000,
    maxXP: 999999999,
    tier: 'Supreme',
    tierTheme: 'Enlightenment & Legacy',
    description: 'The ultimate symbol of knowledge, balance, and purpose. You have not only learned but helped others see.',
    achievements: 'Legendary record — platform ambassador, multi-year engagement.',
    psychology: 'Final self-actualization tier; the "endgame" of Uriel.',
    color: '#FFD700',
    visualTheme: 'Pure white-gold radiance, glowing halo motif',
    isUltimate: true
  }
];

// Upload function
async function uploadRankImages() {
  console.log('🚀 Starting Leaderboard Rank Upload...\n');
  
  const assetsDir = path.join(__dirname, 'assets', 'leaderboards_rank');
  
  // Check if directory exists
  if (!fs.existsSync(assetsDir)) {
    console.error('❌ Directory not found:', assetsDir);
    return;
  }
  
  const files = fs.readdirSync(assetsDir);
  console.log(`📁 Found ${files.length} files in leaderboards_rank folder\n`);
  
  let uploadedCount = 0;
  let errorCount = 0;
  
  for (const rankInfo of RANK_DATA) {
    const rankNumber = rankInfo.rank;
    
    // Find the image file (could be .png or .jpg)
    const imageFile = files.find(f => 
      f.startsWith(`rank_${rankNumber}.`) && (f.endsWith('.png') || f.endsWith('.jpg'))
    );
    
    if (!imageFile) {
      console.log(`⚠️  Warning: No image found for Rank ${rankNumber} (${rankInfo.name})`);
      errorCount++;
      continue;
    }
    
    try {
      const filePath = path.join(assetsDir, imageFile);
      const fileExtension = path.extname(imageFile);
      const storageFileName = `leaderboard_ranks/rank_${rankNumber}${fileExtension}`;
      
      // Upload to Firebase Storage
      await bucket.upload(filePath, {
        destination: storageFileName,
        metadata: {
          contentType: fileExtension === '.png' ? 'image/png' : 'image/jpeg',
          metadata: {
            rankNumber: rankNumber.toString(),
            rankName: rankInfo.name,
            uploadedAt: new Date().toISOString()
          }
        }
      });
      
      // Make the file publicly accessible
      const file = bucket.file(storageFileName);
      await file.makePublic();
      
      // Get the public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storageFileName}`;
      
      // Create/Update Firestore document
      await db.collection('leaderboardRanks').doc(`rank_${rankNumber}`).set({
        rank: rankNumber,
        name: rankInfo.name,
        minXP: rankInfo.minXP,
        maxXP: rankInfo.maxXP,
        tier: rankInfo.tier,
        tierTheme: rankInfo.tierTheme,
        description: rankInfo.description,
        achievements: rankInfo.achievements || '',
        psychology: rankInfo.psychology || '',
        meaning: rankInfo.meaning || '',
        color: rankInfo.color,
        visualTheme: rankInfo.visualTheme || '',
        imageUrl: publicUrl,
        isUltimate: rankInfo.isUltimate || false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`✅ Rank ${rankNumber}: ${rankInfo.name} (${rankInfo.minXP.toLocaleString()}-${rankInfo.maxXP.toLocaleString()} XP)`);
      console.log(`   📷 Image: ${imageFile}`);
      console.log(`   🔗 URL: ${publicUrl}`);
      console.log(`   💾 Firestore: leaderboardRanks/rank_${rankNumber}\n`);
      
      uploadedCount++;
      
    } catch (error) {
      console.error(`❌ Error uploading Rank ${rankNumber} (${rankInfo.name}):`, error.message);
      errorCount++;
    }
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('📊 UPLOAD SUMMARY');
  console.log('='.repeat(60));
  console.log(`✅ Successfully uploaded: ${uploadedCount} ranks`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log(`📦 Total ranks: ${RANK_DATA.length}`);
  console.log('='.repeat(60));
  
  // Create a metadata document for quick reference
  await db.collection('leaderboardMetadata').doc('ranks_info').set({
    totalRanks: RANK_DATA.length,
    minXP: 0,
    maxXP: 999999999,
    tiers: ['Beginner', 'Achiever', 'Advanced', 'Expert', 'Prestige', 'Supreme'],
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    version: '1.0'
  });
  
  console.log('\n✨ Metadata document created: leaderboardMetadata/ranks_info');
  console.log('\n🎉 Upload complete!\n');
}

// Helper function to get rank by XP
async function createRankHelperFunction() {
  console.log('\n📝 Creating helper function document...');
  
  const rankRanges = RANK_DATA.map(r => ({
    rank: r.rank,
    name: r.name,
    minXP: r.minXP,
    maxXP: r.maxXP,
    tier: r.tier,
    color: r.color
  }));
  
  await db.collection('leaderboardMetadata').doc('rank_ranges').set({
    ranges: rankRanges,
    note: 'Use this document to quickly determine user rank based on XP',
    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log('✅ Helper document created: leaderboardMetadata/rank_ranges');
}

// Run the upload
uploadRankImages()
  .then(() => createRankHelperFunction())
  .then(() => {
    console.log('\n✨ All done! Your leaderboard ranks are now in Firebase.');
    console.log('\n📖 Usage in your app:');
    console.log('   1. Query: db.collection("leaderboardRanks").where("minXP", "<=", userXP).where("maxXP", ">=", userXP)');
    console.log('   2. Or use: leaderboardMetadata/rank_ranges for client-side calculation');
    console.log('   3. Display imageUrl for the rank badge\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
