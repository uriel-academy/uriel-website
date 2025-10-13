const admin = require("firebase-admin");
const fs = require("fs");

// Load service account JSON
const serviceAccount = require("./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "uriel-academy-41fb0"
});

const db = admin.firestore();

async function importCountryTrivia() {
  try {
    console.log("🌍 Starting country trivia import...");

    // Read the JSON files
    const questionsRaw = fs.readFileSync("./assets/trivia/country_questions.json", "utf8");
    const answersRaw = fs.readFileSync("./assets/trivia/country_answers.json", "utf8");

    const questions = JSON.parse(questionsRaw);
    const answers = JSON.parse(answersRaw);

    console.log(`📚 Found ${Object.keys(questions).length} questions`);

    // Reference to trivia collection
    const triviaRef = db.collection("trivia");

    let successCount = 0;
    let errorCount = 0;

    // Process each question
    for (const [questionId, questionData] of Object.entries(questions)) {
      try {
        const correctAnswer = answers[questionId];
        
        if (!correctAnswer) {
          console.warn(`⚠️ No answer found for ${questionId}`);
          errorCount++;
          continue;
        }

        // Create the trivia document
        const triviaDoc = {
          question: questionData.question,
          options: questionData.possibleAnswers,
          correctAnswer: correctAnswer,
          category: "Country Capitals",
          difficulty: "medium",
          explanation: `The capital of this country is ${correctAnswer.substring(3)}.`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          isActive: true,
          type: "multiple_choice"
        };

        // Add to Firestore
        await triviaRef.add(triviaDoc);
        
        successCount++;
        
        if (successCount % 10 === 0) {
          console.log(`✅ Imported ${successCount} questions...`);
        }
      } catch (error) {
        console.error(`❌ Error importing ${questionId}:`, error.message);
        errorCount++;
      }
    }

    console.log("\n📊 Import Summary:");
    console.log(`✅ Successfully imported: ${successCount} questions`);
    console.log(`❌ Errors: ${errorCount}`);
    console.log(`📈 Total processed: ${successCount + errorCount}`);
    console.log("\n🎉 Country trivia import complete!");

  } catch (error) {
    console.error("💥 Fatal error:", error);
    process.exit(1);
  }
}

// Run the import
importCountryTrivia()
  .then(() => {
    console.log("✨ Script finished successfully");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Script failed:", error);
    process.exit(1);
  });
