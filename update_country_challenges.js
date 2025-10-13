const admin = require("firebase-admin");

// Initialize Firebase Admin if not already initialized
try {
  admin.app();
} catch (e) {
  const serviceAccount = require("./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: "uriel-academy-41fb0"
  });
}

const db = admin.firestore();

async function updateCountryChallenges() {
  try {
    console.log("🌍 Creating Country category trivia challenges...\n");

    // Delete the geography challenges we just created
    const geoChallenges = await db.collection("trivia_challenges")
      .where("title", "in", [
        "World Capitals Challenge",
        "African Capitals Quiz", 
        "European Capitals Challenge",
        "Asian Capitals Master",
        "Americas Geography Quiz"
      ])
      .get();

    console.log(`🗑️  Removing ${geoChallenges.size} geography challenges...\n`);
    
    const deleteBatch = db.batch();
    geoChallenges.forEach((doc) => {
      deleteBatch.delete(doc.ref);
    });
    await deleteBatch.commit();

    // Create NEW challenges for "Country" category
    const challenges = [
      {
        title: "World Capitals Challenge",
        description: "Test your knowledge of world capitals! Can you match countries with their capital cities?",
        category: "Country",
        difficulty: "Medium",
        gameMode: "Quick Play",
        questionCount: 194,
        timeLimit: 30,
        points: 500,
        isNew: true,
        isActive: true,
        createdDate: new Date().toISOString(),
        expiryDate: null,
        participants: 0,
        tags: ["country", "capitals", "countries", "world", "cities"],
        imageUrl: "🌍",
        rules: {
          allowSkip: true,
          showExplanations: true,
          randomizeQuestions: true,
          randomizeOptions: true
        },
        minLevel: 1,
        isMultiplayer: false,
        maxPlayers: 1
      },
      {
        title: "African Capitals Quiz",
        description: "How well do you know African capital cities? Test your knowledge!",
        category: "Country",
        difficulty: "Easy",
        gameMode: "Quick Play",
        questionCount: 54,
        timeLimit: 15,
        points: 300,
        isNew: true,
        isActive: true,
        createdDate: new Date().toISOString(),
        expiryDate: null,
        participants: 0,
        tags: ["country", "africa", "capitals"],
        imageUrl: "🌍",
        rules: {
          allowSkip: true,
          showExplanations: true,
          randomizeQuestions: true,
          randomizeOptions: true
        },
        minLevel: 1,
        isMultiplayer: false,
        maxPlayers: 1
      },
      {
        title: "European Capitals Challenge",
        description: "From Paris to Prague, test your knowledge of European capitals!",
        category: "Country",
        difficulty: "Medium",
        gameMode: "Quick Play",
        questionCount: 44,
        timeLimit: 15,
        points: 350,
        isNew: false,
        isActive: true,
        createdDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
        expiryDate: null,
        participants: 156,
        tags: ["country", "europe", "capitals"],
        imageUrl: "🇪🇺",
        rules: {
          allowSkip: true,
          showExplanations: true,
          randomizeQuestions: true,
          randomizeOptions: true
        },
        minLevel: 1,
        isMultiplayer: false,
        maxPlayers: 1
      },
      {
        title: "Asian Capitals Master",
        description: "Challenge yourself with the diverse capitals of Asia!",
        category: "Country",
        difficulty: "Hard",
        gameMode: "Tournament",
        questionCount: 48,
        timeLimit: 20,
        points: 450,
        isNew: true,
        isActive: true,
        createdDate: new Date().toISOString(),
        expiryDate: null,
        participants: 42,
        tags: ["country", "asia", "capitals"],
        imageUrl: "🌏",
        rules: {
          allowSkip: false,
          showExplanations: false,
          randomizeQuestions: true,
          randomizeOptions: true
        },
        minLevel: 2,
        isMultiplayer: false,
        maxPlayers: 1
      },
      {
        title: "Americas Capital Cities",
        description: "From North to South America, test your capital city knowledge!",
        category: "Country",
        difficulty: "Medium",
        gameMode: "Quick Play",
        questionCount: 35,
        timeLimit: 15,
        points: 350,
        isNew: false,
        isActive: true,
        createdDate: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(),
        expiryDate: null,
        participants: 89,
        tags: ["country", "americas", "capitals"],
        imageUrl: "🌎",
        rules: {
          allowSkip: true,
          showExplanations: true,
          randomizeQuestions: true,
          randomizeOptions: true
        },
        minLevel: 1,
        isMultiplayer: false,
        maxPlayers: 1
      }
    ];

    // Add new challenges with "Country" category
    let count = 0;
    for (const challenge of challenges) {
      await db.collection("trivia_challenges").add(challenge);
      count++;
      console.log(`✅ Added: ${challenge.title} (Category: ${challenge.category})`);
    }

    console.log(`\n🎉 Successfully added ${count} trivia challenges to "Country" category!`);

  } catch (error) {
    console.error("💥 Error:", error);
    process.exit(1);
  }
}

updateCountryChallenges()
  .then(() => {
    console.log("\n✨ Script complete");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Failed:", error);
    process.exit(1);
  });
