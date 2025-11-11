# English Comprehension Questions Implementation Guide

## Overview
This system adds support for comprehension passages and section instructions to the Uriel Academy question system. It's designed to be **fully backward compatible** - existing questions without passages continue to work exactly as before.

## Features

### 1. **Reading Comprehension Passages**
- Passages are stored in a separate `passages` collection for reusability
- Multiple questions can reference the same passage
- Passages display in a collapsible card above questions
- Beautiful, readable formatting with proper typography

### 2. **Section Instructions**
- Instructions like "Choose the word closest in meaning" display prominently
- Shown in a highlighted yellow box with an info icon
- Applied to specific question ranges (e.g., Q30-35)

### 3. **Smart Caching**
- Passages are fetched once and cached per quiz session
- Reduces Firestore reads and improves performance
- Seamless user experience with no flickering

## Data Structure

### Passage Model
```dart
class Passage {
  final String id;                    // e.g., "english_2022_passage_1"
  final String title;                 // e.g., "The Farmer's Son"
  final String content;               // Full passage text
  final Subject subject;              // Subject.english
  final ExamType examType;            // ExamType.bece
  final String year;                  // "2022"
  final String section;               // "A", "B", "C"
  final List<int> questionRange;      // [1, 2, 3, 4, 5]
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;
}
```

### Question Model (New Optional Fields)
```dart
class Question {
  // ... existing fields ...
  
  // New optional fields
  final String? passageId;                  // Reference to passage
  final String? sectionInstructions;        // Instructions for question section
  final List<int>? relatedQuestions;        // Questions sharing same instructions
}
```

## JSON Format

### Sample Structure
See `bece_english_sample.json` for a complete example. Here's the structure:

```json
{
  "passages": [
    {
      "id": "english_2022_passage_1",
      "title": "The Farmer's Son",
      "content": "Once upon a time...",
      "subject": "english",
      "examType": "bece",
      "year": "2022",
      "section": "A",
      "questionRange": [1, 2, 3, 4, 5]
    }
  ],
  "questions": [
    {
      "id": "english_2022_q1",
      "questionText": "From the passage, what was the farmer worried about?",
      "type": "multipleChoice",
      "subject": "english",
      "examType": "bece",
      "year": "2022",
      "section": "A",
      "questionNumber": 1,
      "passageId": "english_2022_passage_1",
      "options": ["A. His health", "B. His sons' laziness", "C. His crops", "D. His neighbors"],
      "correctAnswer": "B",
      "marks": 1,
      "difficulty": "easy",
      "topics": ["Reading Comprehension", "Inference"],
      "createdBy": "admin",
      "isActive": true
    }
  ]
}
```

### Question Types

#### 1. Questions with Passages
```json
{
  "id": "english_2022_q1",
  "questionText": "From the passage, what was the farmer worried about?",
  "passageId": "english_2022_passage_1",
  ...
}
```

#### 2. Questions with Section Instructions (No Passage)
```json
{
  "id": "english_2022_q30",
  "questionText": "Choose the word closest in meaning to 'critical'.",
  "sectionInstructions": "From questions 30 to 35, choose the word closest in meaning to the underlined word.",
  "relatedQuestions": [30, 31, 32, 33, 34, 35],
  ...
}
```

#### 3. Regular Questions (Backward Compatible)
```json
{
  "id": "english_2022_q40",
  "questionText": "The teacher asked the students to _____ their homework.",
  "options": ["A. submit", "B. submits", "C. submitted", "D. submitting"],
  "correctAnswer": "A",
  ...
}
```

## Usage

### Importing English Questions

1. **Prepare your JSON file** following the format in `bece_english_sample.json`

2. **Run the import script:**
```powershell
node import_bece_english.js --file=./your_english_file.json --serviceAccount=./your-service-account.json
```

3. **Default values:**
   - File: `./bece_english_sample.json`
   - Service Account: `./uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json`

### Import Process

The script:
1. ✅ Validates JSON structure
2. ✅ Imports all passages to `passages` collection
3. ✅ Imports all questions to `questions` collection
4. ✅ Links questions to passages via `passageId`
5. ✅ Adds section instructions where specified
6. ✅ Provides detailed import summary

### Example Output
```
🚀 Starting BECE English Questions Import...

📖 Loaded data from: ./bece_english_sample.json
   Passages: 2
   Questions: 8

📚 Importing passages...
✅ Imported 2 passages successfully!

❓ Importing questions...
✅ Imported 8 questions successfully!
   📚 Questions with passages: 5
   📋 Questions with instructions: 3

═══════════════════════════════════════════
✅ Import completed successfully!
   Total passages: 2
   Total questions: 8
═══════════════════════════════════════════
```

## UI Behavior

### Passage Display
- **Collapsible:** Users can expand/collapse passages to save screen space
- **Beautiful formatting:** Uses Playfair Display for title, Montserrat for content
- **Light background:** Soft gray (#F5F5F5) for comfortable reading
- **Icon:** Book icon indicates reading material
- **Smart positioning:** Always appears above the question

### Section Instructions
- **Highlighted box:** Soft yellow background (#FFF9E6) stands out
- **Info icon:** Orange info icon draws attention
- **Clear typography:** Bold Montserrat font
- **Positioned:** Between passage (if any) and question

### Question Card
- **Unchanged:** Questions without passages/instructions look exactly the same
- **Seamless integration:** Passage-based questions blend naturally with UI
- **Responsive:** Works on mobile and desktop

## Firestore Collections

### Passages Collection
```
passages/
  ├── english_2022_passage_1
  │   ├── id: "english_2022_passage_1"
  │   ├── title: "The Farmer's Son"
  │   ├── content: "Once upon a time..."
  │   ├── subject: "english"
  │   ├── examType: "bece"
  │   ├── year: "2022"
  │   ├── section: "A"
  │   ├── questionRange: [1, 2, 3, 4, 5]
  │   ├── createdAt: Timestamp
  │   ├── createdBy: "admin"
  │   └── isActive: true
  └── ...
```

### Questions Collection (Enhanced)
```
questions/
  ├── english_2022_q1
  │   ├── ... (existing fields)
  │   ├── passageId: "english_2022_passage_1"  [NEW]
  │   └── sectionInstructions: null
  ├── english_2022_q30
  │   ├── ... (existing fields)
  │   ├── passageId: null
  │   ├── sectionInstructions: "Choose the word..."  [NEW]
  │   └── relatedQuestions: [30, 31, 32, 33, 34, 35]  [NEW]
  └── ...
```

## Code Architecture

### Models
- `lib/models/passage_model.dart` - Passage data structure
- `lib/models/question_model.dart` - Enhanced Question with optional fields

### UI Components
- `lib/screens/quiz_taker_page.dart` - Enhanced with passage support
  - `_buildPassageSection()` - Renders collapsible passage
  - `_buildSectionInstructions()` - Renders instruction box
  - `_fetchPassage()` - Fetches and caches passages
  - `_buildQuestionCard()` - Enhanced to show passages/instructions

### Import Script
- `import_bece_english.js` - Imports passages and questions

### Sample Data
- `bece_english_sample.json` - Example data structure

## Performance Optimization

### Caching Strategy
```dart
Map<String, Passage> passageCache = {};

Future<Passage?> _fetchPassage(String passageId) async {
  // Check cache first
  if (passageCache.containsKey(passageId)) {
    return passageCache[passageId];
  }
  
  // Fetch from Firestore
  final passage = await FirebaseFirestore.instance
      .collection('passages')
      .doc(passageId)
      .get();
  
  // Cache for future use
  passageCache[passageId] = passage;
  
  return passage;
}
```

**Benefits:**
- ✅ Passages fetched only once per quiz
- ✅ No redundant Firestore reads
- ✅ Instant display when navigating between questions
- ✅ Reduced costs and improved speed

## Testing Checklist

- [ ] Import sample data: `node import_bece_english.js`
- [ ] Verify passages in Firestore Console
- [ ] Verify questions in Firestore Console
- [ ] Create English quiz in app
- [ ] Check passage displays correctly
- [ ] Check section instructions display
- [ ] Test passage collapse/expand
- [ ] Test on mobile device
- [ ] Test with existing (non-English) questions
- [ ] Verify backward compatibility
- [ ] Check performance with 20+ questions

## Backward Compatibility

✅ **Fully backward compatible:**
- Questions without `passageId` work exactly as before
- Questions without `sectionInstructions` work as before
- Existing questions need no modification
- New fields are optional (`String?`, `List<int>?`)
- toJson/fromJson handle missing fields gracefully

## Best Practices

### Creating Passages
1. Use descriptive IDs: `english_2022_passage_1`
2. Write clear, engaging titles
3. Keep passages 150-300 words for readability
4. Specify accurate questionRange

### Creating Questions
1. Always set `passageId` for comprehension questions
2. Use `sectionInstructions` for question groups
3. Include `relatedQuestions` to show instruction only once
4. Write clear, unambiguous question text

### Import Tips
1. Validate JSON before importing (use JSONLint)
2. Test with small datasets first
3. Back up Firestore before large imports
4. Review import summary carefully
5. Check questions in the app after import

## Troubleshooting

### Passage Not Displaying
- Check `passageId` matches passage document ID
- Verify passage exists in `passages` collection
- Check browser console for errors

### Section Instructions Not Showing
- Ensure `sectionInstructions` field is not null/empty
- Check spelling of field name in JSON

### Import Failing
- Validate JSON syntax
- Check Firebase credentials
- Ensure collections have proper permissions
- Review error messages in console

## Future Enhancements

Potential improvements:
- [ ] Audio passages for listening comprehension
- [ ] Image-based passages
- [ ] Multi-passage questions
- [ ] Passage highlighting/annotation
- [ ] Dictionary lookup within passages
- [ ] Translation support

## Support

For questions or issues:
1. Check this documentation
2. Review `bece_english_sample.json` for examples
3. Check browser/server console for errors
4. Review Firestore data structure

---

**Created:** December 2024  
**Last Updated:** December 2024  
**Version:** 1.0.0
