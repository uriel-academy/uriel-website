# Mathematics BECE Questions Import Guide

## Overview
This guide covers importing mathematics BECE past questions (1990-2025) from `.docx` files with embedded images into Firebase Firestore.

## Key Features Implemented

### Multi-Position Image Support
The Question model now supports 3 types of images:

1. **imageBeforeQuestion**: Context diagrams shown ABOVE the question text
   - Example: Geometry figures, charts that need to be studied first
   - Use case: "Study the triangle ABC above and calculate..."

2. **imageAfterQuestion**: Analysis figures shown BELOW the question text
   - Example: Graphs, tables, diagrams referenced in the question
   - Use case: "What is the area of the shape shown below?"

3. **optionImages**: Visual options (Map<String, String>)
   - Example: Multiple shape images as answer choices
   - Format: `{"A": "url1", "B": "url2", "C": "url3", "D": "url4"}`
   - Use case: "Which of the following is a parallelogram?"

4. **imageUrl**: Legacy single image field (still supported for backward compatibility)

### Quiz Taker UI Updates
The quiz taker now intelligently displays images:
- Shows `imageBeforeQuestion` at the top before question text
- Shows `imageAfterQuestion` after question text but before options
- Shows `optionImages` as thumbnails below each option letter
- All images are tappable to open full-screen interactive viewer
- Images are limited to 150px height in options for better UX

## JSON Schema for Mathematics Questions

```json
{
  "year": "2024",
  "subject": "mathematics",
  "multiple_choice": {
    "q1": {
      "question": "Calculate the area of the triangle ABC.",
      "imageBeforeQuestion": "assets/mathematics/math_2024_q1_before.png",
      "possibleAnswers": {
        "A": "12 cm²",
        "B": "24 cm²",
        "C": "36 cm²",
        "D": "48 cm²"
      },
      "correctAnswer": "B",
      "explanation": "Area = ½ × base × height = ½ × 6 × 8 = 24 cm²"
    },
    "q2": {
      "question": "Study the graph shown and determine the y-intercept.",
      "imageAfterQuestion": "assets/mathematics/math_2024_q2_after.png",
      "possibleAnswers": {
        "A": "2",
        "B": "3",
        "C": "4",
        "D": "5"
      },
      "correctAnswer": "B"
    },
    "q3": {
      "question": "Which of the following shapes is a parallelogram?",
      "optionImages": {
        "A": "assets/mathematics/math_2024_q3_optionA.png",
        "B": "assets/mathematics/math_2024_q3_optionB.png",
        "C": "assets/mathematics/math_2024_q3_optionC.png",
        "D": "assets/mathematics/math_2024_q3_optionD.png"
      },
      "possibleAnswers": {
        "A": "Shape A",
        "B": "Shape B",
        "C": "Shape C",
        "D": "Shape D"
      },
      "correctAnswer": "C"
    }
  }
}
```

## Step-by-Step Import Process

### Step 1: Document Conversion (Manual - Use Pandoc or Word)

For each `.docx` file in `assets/Mathematics/`:

1. **Extract Images**:
   ```bash
   # Unzip the docx (it's actually a zip file)
   mkdir temp_math_2024
   unzip "BECE Past Questions - Mathematics 2024.docx" -d temp_math_2024
   
   # Images are in temp_math_2024/word/media/
   # Rename images with convention:
   # math_<year>_q<number>_<position>.png
   # where position = "before" | "after" | "optionA" | "optionB" | "optionC" | "optionD"
   ```

2. **Convert to JSON**:
   - Open the `.docx` file
   - For each question, determine:
     - Is there an image ABOVE the question text? → `imageBeforeQuestion`
     - Is there an image BELOW the question text? → `imageAfterQuestion`
     - Are the options themselves images? → `optionImages`
   - Structure according to the JSON schema above

3. **Image Naming Convention**:
   ```
   assets/mathematics/
     ├── math_1990_q1_before.png     # Context image for Q1
     ├── math_1990_q2_after.png      # Analysis figure for Q2
     ├── math_1990_q15_optionA.png   # Visual option A for Q15
     ├── math_1990_q15_optionB.png   # Visual option B for Q15
     ├── math_1990_q15_optionC.png   # Visual option C for Q15
     ├── math_1990_q15_optionD.png   # Visual option D for Q15
     └── ...
   ```

### Step 2: Create Import Script

Create `import_mathematics.js` in the project root:

```javascript
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importMathematics() {
  const files = fs.readdirSync('./assets/mathematics_json').filter(f => f.endsWith('.json'));
  
  for (const file of files) {
    console.log(`\n📚 Processing ${file}...`);
    const data = JSON.parse(fs.readFileSync(`./assets/mathematics_json/${file}`, 'utf8'));
    
    const { year, subject, multiple_choice } = data;
    let imported = 0;
    let skipped = 0;
    
    for (const [qKey, qData] of Object.entries(multiple_choice)) {
      const questionNumber = parseInt(qKey.replace('q', ''));
      
      // Build options array from possibleAnswers
      const options = Object.entries(qData.possibleAnswers).map(([letter, text]) => `${letter}. ${text}`);
      
      // Build the question document
      const questionDoc = {
        year,
        subject,
        questionNumber,
        questionText: qData.question,
        options,
        correctAnswer: qData.correctAnswer,
        explanation: qData.explanation || '',
        imageUrl: qData.imageUrl || null,
        imageBeforeQuestion: qData.imageBeforeQuestion || null,
        imageAfterQuestion: qData.imageAfterQuestion || null,
        optionImages: qData.optionImages || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Check if question already exists
      const existingQuery = await db.collection('questions')
        .where('year', '==', year)
        .where('subject', '==', subject)
        .where('questionNumber', '==', questionNumber)
        .limit(1)
        .get();
      
      if (!existingQuery.empty) {
        console.log(`  ⏭️  Q${questionNumber}: Already exists, skipping`);
        skipped++;
        continue;
      }
      
      // Add to Firestore
      await db.collection('questions').add(questionDoc);
      console.log(`  ✅ Q${questionNumber}: Imported`);
      imported++;
    }
    
    console.log(`\n📊 ${file} Summary: ${imported} imported, ${skipped} skipped`);
  }
  
  console.log('\n✨ Mathematics import complete!');
}

importMathematics()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('❌ Import failed:', error);
    process.exit(1);
  });
```

### Step 3: Cloud Function for Mathematics Import

Add to `functions/src/index.ts`:

```typescript
export const importMathematicsQuestions = onRequest(
  { cors: true, timeoutSeconds: 540 },
  async (req, res) => {
    try {
      logger.info("Starting mathematics questions import...");

      const jsonFiles = [
        "bece_mathematics_1990.json",
        "bece_mathematics_1991.json",
        // ... add all years
        "bece_mathematics_2025.json"
      ];

      let totalImported = 0;
      let totalSkipped = 0;

      for (const fileName of jsonFiles) {
        logger.info(`Processing ${fileName}...`);
        
        const filePath = path.join(__dirname, "..", "seed", "mathematics", fileName);
        
        if (!fs.existsSync(filePath)) {
          logger.warn(`File not found: ${fileName}, skipping`);
          continue;
        }

        const fileContent = fs.readFileSync(filePath, "utf8");
        const data = JSON.parse(fileContent);

        const { year, subject, multiple_choice } = data;

        for (const [qKey, qData] of Object.entries(multiple_choice)) {
          const questionNumber = parseInt(qKey.replace("q", ""));

          // Build options array
          const possibleAnswers = qData.possibleAnswers as Record<string, string>;
          const options = Object.entries(possibleAnswers).map(
            ([letter, text]) => `${letter}. ${text}`
          );

          // Check if question exists
          const existingQuery = await db
            .collection("questions")
            .where("year", "==", year)
            .where("subject", "==", subject)
            .where("questionNumber", "==", questionNumber)
            .limit(1)
            .get();

          if (!existingQuery.empty) {
            logger.info(`Q${questionNumber} already exists, skipping`);
            totalSkipped++;
            continue;
          }

          // Create question document
          const questionDoc = {
            year,
            subject,
            questionNumber,
            questionText: qData.question,
            options,
            correctAnswer: qData.correctAnswer,
            explanation: qData.explanation || "",
            imageUrl: qData.imageUrl || null,
            imageBeforeQuestion: qData.imageBeforeQuestion || null,
            imageAfterQuestion: qData.imageAfterQuestion || null,
            optionImages: qData.optionImages || null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          };

          await db.collection("questions").add(questionDoc);
          logger.info(`Q${questionNumber} imported successfully`);
          totalImported++;
        }
      }

      logger.info(`Import complete: ${totalImported} imported, ${totalSkipped} skipped`);

      return res.status(200).json({
        success: true,
        imported: totalImported,
        skipped: totalSkipped,
      });
    } catch (error) {
      logger.error("Import failed:", error);
      return res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
);
```

### Step 4: Upload Images to Firebase Storage

For network URLs instead of assets, upload to Firebase Storage:

```javascript
const { Storage } = require('@google-cloud/storage');
const storage = new Storage();
const bucket = storage.bucket('uriel-academy-41fb0.appspot.com');

async function uploadMathImages() {
  const files = fs.readdirSync('./assets/mathematics').filter(f => f.endsWith('.png') || f.endsWith('.jpg'));
  
  for (const file of files) {
    const localPath = `./assets/mathematics/${file}`;
    const remotePath = `mathematics/${file}`;
    
    await bucket.upload(localPath, {
      destination: remotePath,
      metadata: {
        contentType: 'image/png',
        cacheControl: 'public, max-age=31536000',
      },
    });
    
    // Make publicly readable
    await bucket.file(remotePath).makePublic();
    
    const publicUrl = `https://storage.googleapis.com/uriel-academy-41fb0.appspot.com/${remotePath}`;
    console.log(`✅ ${file} → ${publicUrl}`);
  }
}
```

## Decision Matrix: Asset vs Network Images

### Use Assets (`assets/mathematics/`) when:
- ✅ Images are bundled with the app
- ✅ Offline access is critical
- ✅ Total size is manageable (< 20MB)
- ✅ Images rarely change

### Use Firebase Storage (Network URLs) when:
- ✅ Images are large or numerous (> 20MB total)
- ✅ Need to update images without redeploying app
- ✅ Images are shared across web and mobile
- ✅ CDN caching benefits are important

## Testing Checklist

After import, verify:

1. **Model Serialization**:
   ```dart
   // Test in Dart DevTools or unit tests
   final question = Question.fromJson(firestoreDoc.data());
   print(question.imageBeforeQuestion); // Should not be null
   print(question.optionImages); // Should be Map<String, String>
   ```

2. **Quiz Taker Display**:
   - [ ] `imageBeforeQuestion` appears ABOVE question text
   - [ ] `imageAfterQuestion` appears AFTER question text, BEFORE options
   - [ ] `optionImages` appear as thumbnails below corresponding options
   - [ ] All images are tappable for full-screen view
   - [ ] Images maintain aspect ratio
   - [ ] Loading states show properly

3. **Data Integrity**:
   ```javascript
   // Run in Firebase console
   db.collection('questions')
     .where('subject', '==', 'mathematics')
     .where('year', '==', '2024')
     .get()
     .then(snap => {
       console.log(`Found ${snap.size} questions`);
       snap.forEach(doc => {
         const data = doc.data();
         if (data.imageBeforeQuestion) console.log(`Q${data.questionNumber} has imageBeforeQuestion`);
         if (data.optionImages) console.log(`Q${data.questionNumber} has ${Object.keys(data.optionImages).length} option images`);
       });
     });
   ```

## Troubleshooting

### Images not displaying in quiz taker
- Check that image paths are correct (assets/ prefix for local, https:// for network)
- Verify images are in `pubspec.yaml` under assets
- Run `flutter clean && flutter pub get`
- Check browser console for 404 errors

### optionImages not rendering
- Ensure optionImages is a Map<String, String> in JSON
- Keys must match option letters (A, B, C, D)
- Verify fromJson() correctly parses the map

### Images too large/slow to load
- Optimize images (reduce resolution, compress)
- Consider lazy loading for option images
- Use CachedNetworkImage for network images (already implemented)

## Performance Considerations

- **Asset images**: Increase app bundle size but load instantly
- **Network images**: Smaller bundle but require internet connection
- **Option images**: Set reasonable max height (150px) to prevent layout issues
- **Caching**: CachedNetworkImage automatically caches network images

## Next Steps

1. **Convert first year** (e.g., 2024) as a test
2. **Import and verify** display in quiz taker
3. **Iterate on conversion process** based on learnings
4. **Batch convert** remaining years (1990-2023)
5. **Deploy to production** after thorough testing

## Related Files

- `lib/models/question_model.dart` - Question model with multi-image support
- `lib/screens/quiz_taker_page.dart` - Quiz UI with image display logic
- `functions/src/index.ts` - Cloud Functions for import
- `assets/Mathematics/` - Source .docx files (36 years)
- `assets/mathematics/` - Extracted images (create this folder)

---

**Status**: Schema implemented ✅ | UI updated ✅ | Import scripts pending ⏳
