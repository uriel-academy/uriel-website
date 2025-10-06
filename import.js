const admin = require("firebase-admin");
const fs = require("fs");

// Load service account JSON (make sure filename matches yours exactly)
const serviceAccount = require("./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json");

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "uriel-academy-41fb0"
});

const db = admin.firestore();

async function importQuestions() {
  // Read the JSON file
  const raw = fs.readFileSync("./bece_1999_questions.json", "utf8");
  let questions = JSON.parse(raw);

  // 🔑 Fix: Convert object → array if needed
  if (!Array.isArray(questions)) {
    questions = Object.values(questions);
  }

  const paperRef = db
    .collection("exams").doc("bece")
    .collection("subjects").doc("rme")
    .collection("papers").doc("1999");

  // Ensure parent docs exist
  await db.collection("exams").doc("bece").set({ name: "BECE" }, { merge: true });
  await db.collection("exams").doc("bece").collection("subjects").doc("rme").set({ name: "RME" }, { merge: true });
  await paperRef.set({ year: 1999 }, { merge: true });

  // Import all questions
  let count = 0;
  const batch = db.batch();

  for (const q of questions) {
    count++;
    const qRef = paperRef.collection("questions").doc(String(q.number || count));

    batch.set(qRef, {
      number: q.number || count,
      type: q.type || "mcq",
      question: q.question || "",
      options: q.options || [q.A, q.B, q.C, q.D].filter(Boolean),
      answer: q.answer || null,
      explanation: q.explanation || "",
      marks: q.marks || 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }

  await batch.commit();
  console.log(`✅ Imported ${questions.length} questions into Firestore`);
}

importQuestions().catch(console.error);
