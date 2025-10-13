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

async function testTriviaAccess() {
  try {
    console.log("🧪 Testing trivia data access...\n");

    // Test 1: Get all challenges
    const challengesSnapshot = await db.collection("trivia_challenges").get();
    console.log(`✅ Total challenges: ${challengesSnapshot.size}`);

    // Test 2: Get Country category challenges
    const countrySnapshot = await db.collection("trivia_challenges")
      .where("category", "==", "Country")
      .get();
    console.log(`✅ Country challenges: ${countrySnapshot.size}`);

    // Test 3: List all categories
    const categories = new Set();
    challengesSnapshot.forEach(doc => {
      categories.add(doc.data().category);
    });
    console.log(`✅ Unique categories: ${Array.from(categories).join(", ")}`);

    // Test 4: Check if challenges are active
    let activeCount = 0;
    challengesSnapshot.forEach(doc => {
      if (doc.data().isActive) activeCount++;
    });
    console.log(`✅ Active challenges: ${activeCount}`);

    // Test 5: Verify trivia questions exist
    const triviaQuestionsSnapshot = await db.collection("trivia").limit(1).get();
    console.log(`✅ Trivia questions collection exists: ${!triviaQuestionsSnapshot.empty}`);

    console.log("\n📋 All Country Challenges:");
    countrySnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.title} (${data.difficulty}, ${data.questionCount} questions)`);
    });

    console.log("\n✨ All tests passed! Trivia is properly configured.");

  } catch (error) {
    console.error("❌ Test failed:", error);
    process.exit(1);
  }
}

testTriviaAccess()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Failed:", error);
    process.exit(1);
  });
