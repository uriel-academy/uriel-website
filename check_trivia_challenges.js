const admin = require("firebase-admin");

// Load service account JSON
const serviceAccount = require("./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "uriel-academy-41fb0"
});

const db = admin.firestore();

async function checkTriviaChallenges() {
  try {
    console.log("🔍 Checking trivia_challenges collection...\n");

    const snapshot = await db.collection("trivia_challenges").get();
    
    console.log(`📊 Total challenges: ${snapshot.size}\n`);

    if (snapshot.empty) {
      console.log("❌ No challenges found in trivia_challenges collection!");
      return;
    }

    snapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`Challenge ID: ${doc.id}`);
      console.log(`  Title: ${data.title}`);
      console.log(`  Category: ${data.category}`);
      console.log(`  Difficulty: ${data.difficulty}`);
      console.log(`  Questions: ${data.questionCount}`);
      console.log(`  Active: ${data.isActive}`);
      console.log(`  New: ${data.isNew}`);
      console.log(`---`);
    });

    // Also check trivia questions
    console.log("\n🔍 Checking trivia questions collection...\n");
    
    const triviaSnapshot = await db.collection("trivia").limit(5).get();
    console.log(`📚 Sample of trivia questions (showing 5 of many):\n`);
    
    triviaSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`Question ID: ${doc.id}`);
      console.log(`  Category: ${data.category}`);
      console.log(`  Question: ${data.question?.substring(0, 80)}...`);
      console.log(`---`);
    });

    // Count by category
    const countrySnapshot = await db.collection("trivia")
      .where("category", "==", "Country Capitals")
      .get();
    console.log(`\n✅ Country Capitals questions: ${countrySnapshot.size}`);

  } catch (error) {
    console.error("💥 Error:", error);
  }
}

checkTriviaChallenges()
  .then(() => {
    console.log("\n✨ Check complete");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Failed:", error);
    process.exit(1);
  });
