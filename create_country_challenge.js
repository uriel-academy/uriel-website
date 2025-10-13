const admin = require("firebase-admin");

// Load service account JSON
const serviceAccount = require("./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "uriel-academy-41fb0"
});

const db = admin.firestore();

async function createCountryChallenge() {
  try {
    console.log("🌍 Creating Country Capitals trivia challenge...");

    // Count the number of country questions we have
    const triviaSnapshot = await db.collection("trivia")
      .where("category", "==", "Country Capitals")
      .get();

    const questionCount = triviaSnapshot.size;
    console.log(`📚 Found ${questionCount} country capital questions`);

    if (questionCount === 0) {
      console.error("❌ No country capital questions found in trivia collection!");
      process.exit(1);
    }

    // Create the trivia challenge document
    const challengeData = {
      title: "World Capitals Challenge",
      description: "Test your knowledge of world capitals! Can you match countries with their capital cities?",
      category: "Geography",
      difficulty: "Medium",
      gameMode: "Quick Play",
      questionCount: questionCount,
      timeLimit: 30, // 30 minutes
      points: 500,
      isNew: true,
      isActive: true,
      createdDate: new Date().toISOString(),
      expiryDate: null,
      participants: 0,
      tags: ["geography", "capitals", "countries", "world", "cities"],
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
    };

    // Add to trivia_challenges collection
    const challengeRef = await db.collection("trivia_challenges").add(challengeData);
    
    console.log(`✅ Created challenge with ID: ${challengeRef.id}`);
    console.log("\n📊 Challenge Details:");
    console.log(`   Title: ${challengeData.title}`);
    console.log(`   Category: ${challengeData.category}`);
    console.log(`   Questions: ${challengeData.questionCount}`);
    console.log(`   Difficulty: ${challengeData.difficulty}`);
    console.log(`   Points: ${challengeData.points}`);
    console.log("\n🎉 Country Capitals challenge created successfully!");

  } catch (error) {
    console.error("💥 Error creating challenge:", error);
    process.exit(1);
  }
}

// Run the function
createCountryChallenge()
  .then(() => {
    console.log("✨ Script finished successfully");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Script failed:", error);
    process.exit(1);
  });
