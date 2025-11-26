# Theory Questions - Quick Start Guide

## ✅ What's Been Done

### 1. Data Extraction & Import
- ✅ Extracted **1,388 theory questions** from DOCX files
- ✅ Imported to Firestore collection: `theoryQuestions`
- ✅ 11 subjects, 36 years (1990-2025)

### 2. Flutter UI
- ✅ **Browse Page**: Filter by subject/year, view question cards
- ✅ **Viewer Page**: Split-view (desktop) or tabbed (mobile) with AI tutor
- ✅ **Navigation**: Added to student dashboard (5th quick action button)

### 3. AI Integration
- ✅ Socratic tutoring method (guides, doesn't answer)
- ✅ Real-time SSE streaming
- ✅ Answer submission to `theoryAnswers` collection

### 4. Security
- ✅ Firestore rules deployed
- ✅ Students can read questions, submit answers
- ✅ Teachers can grade (UI not built yet)

---

## 🚀 How to Test

### Step 1: Run the App
```bash
flutter run -d chrome
```

### Step 2: Navigate to Theory Questions
1. Log in as a student
2. On dashboard, click **"Theory Questions"** button (edit icon)
3. You should see the browse page with filters

### Step 3: Try a Question
1. Select a subject (e.g., Mathematics)
2. Select a year (e.g., 2020)
3. Click **"Start"** on any question card
4. Desktop: Split-view appears (question left, chat right)
5. Mobile: Tabbed view (switch between question/chat)

### Step 4: Chat with AI
1. Type a question or thought in the chat
2. AI responds with Socratic guidance (hints, not answers)
3. Continue dialogue to develop your answer
4. Click **"Submit Answer"** button in app bar when ready
5. Success dialog appears, data saved to Firestore

### Step 5: Verify Submission
```javascript
// Firebase Console → Firestore
// Collection: theoryAnswers
// Look for document: {studentId}_{questionId}
```

---

## 📁 Files Changed/Created

### Created Files
```
extract_theory_questions.js          # DOCX → JSON extraction
import_theory_questions.js           # Firestore import script
lib/screens/theory_questions_page.dart    # Browse UI
lib/screens/theory_question_viewer.dart   # Split-view UI
THEORY_QUESTIONS_IMPLEMENTATION.md   # Full documentation
THEORY_QUESTIONS_QUICKSTART.md       # This file
```

### Modified Files
```
functions/src/index.ts                # Added importTheoryQuestions
firestore.rules                       # Added theoryQuestions & theoryAnswers rules
lib/screens/student_dashboard.dart    # Added navigation button
```

### Data Files Created
```
bece_theory_asante_twi.json          (7 questions)
bece_theory_career_technology.json   (12 questions)
bece_theory_creative_arts.json       (11 questions)
bece_theory_english.json             (155 questions)
bece_theory_french.json              (125 questions)
bece_theory_ga.json                  (6 questions)
bece_theory_ict.json                 (80 questions)
bece_theory_mathematics.json         (378 questions)
bece_theory_rme.json                 (203 questions)
bece_theory_integrated_science.json  (182 questions)
bece_theory_social_studies.json      (229 questions)
bece_theory_all.json                 (combined)
bece_theory_summary.json             (statistics)
```

---

## 🎯 User Flow

```
Student Dashboard
    ↓ [Click "Theory Questions"]
Theory Questions Page (Browse)
    ↓ [Filter by subject/year]
    ↓ [Click "Start" on question]
Theory Question Viewer
    ↓ [Read question on left]
    ↓ [Chat with AI tutor on right]
    ↓ [Develop answer through dialogue]
    ↓ [Click "Submit Answer"]
Success Dialog
    ↓ [Return to browse page]
Teacher Reviews (Future)
    ↓ [Grades & feedback]
Student Notification
```

---

## 🔧 Troubleshooting

### Issue: No questions appear
**Fix**: Check Firestore console → `theoryQuestions` collection should have 1388 docs

### Issue: AI chat not responding
**Fix**: Check Cloud Functions logs for `aiChatHttp` errors

### Issue: Submit button does nothing
**Fix**: Check browser console for errors, verify Firestore rules deployed

### Issue: Security rules error
**Fix**: Re-deploy rules: `firebase deploy --only firestore:rules`

### Issue: "Not enough positional arguments" error
**Fix**: Already fixed - ChatService requires URI parameter

---

## 📊 Data Verification

### Check Import Success
```javascript
// Open browser console on Firebase Console
db.collection('theoryQuestions').get().then(snap => {
  console.log('Total questions:', snap.size); // Should be 1388
});

db.collection('app_metadata').doc('content').get().then(doc => {
  console.log(doc.data().theoryQuestionsCount); // Should be 1388
});
```

### Check Answer Submission
```javascript
// After submitting an answer
db.collection('theoryAnswers').get().then(snap => {
  console.log('Total submissions:', snap.size);
  snap.docs.forEach(doc => console.log(doc.data()));
});
```

---

## 🐛 Known Limitations (December Debugging)

1. **Math Rendering**: LaTeX in chat displays as plain text
   - **Workaround**: Type math in plain text for now
   - **Fix**: Add flutter_math_fork parsing (December)

2. **No Draft Saving**: Chat lost if you navigate away
   - **Workaround**: Complete in one session
   - **Fix**: Auto-save every 30 seconds (December)

3. **No Teacher Dashboard**: Grading UI not built
   - **Workaround**: Grade via Firestore console
   - **Fix**: Build teacher review page (December)

4. **Deprecated Warnings**: `withOpacity` deprecation warnings
   - **Impact**: None - just warnings
   - **Fix**: Update to `.withValues()` (December)

---

## 🎓 AI Tutor Behavior

### What It Does
- ✅ Asks Socratic questions ("What do you already know?")
- ✅ Breaks down complex concepts
- ✅ Provides hints and counter-questions
- ✅ Encourages critical thinking
- ✅ Age-appropriate language (14-15 years)

### What It Doesn't Do
- ❌ Give direct answers
- ❌ Write the full answer for you
- ❌ Skip steps or shortcuts
- ❌ Judge or criticize

### Example Dialogue
```
Student: "I don't know how to start"
AI: "Let's break it down! What subject is this question about?"

Student: "It's about triangles"
AI: "Great! What do you know about the different types of triangles?"

Student: "There's right triangles with 90 degrees"
AI: "Perfect! Now, what special property do right triangles have?"

[Continues guiding until student develops full answer]
```

---

## 📱 Mobile vs Desktop

### Desktop (>768px)
```
┌──────────────────────────┬─────────────────────┐
│   Question (40%)         │   AI Chat (60%)     │
│   Read-only display      │   Interactive chat  │
└──────────────────────────┴─────────────────────┘
```

### Mobile (<768px)
```
┌────────────────────────────────┐
│  [Question Tab] [AI Tutor Tab] │
├────────────────────────────────┤
│   Active tab content here      │
└────────────────────────────────┘
```

---

## 🚀 Next Steps (Optional)

### For Users
1. Browse theory questions by favorite subject
2. Practice with AI tutor
3. Submit answers for teacher review
4. Check back for graded feedback (when implemented)

### For Developers
1. Add math rendering to chat messages
2. Build teacher grading dashboard
3. Add answer draft auto-save
4. Implement analytics tracking
5. Add sample answer examples
6. Create progress tracking

---

## 💡 Tips for Students

1. **Be Honest**: Tell the AI what you know and don't know
2. **Ask Questions**: The AI is there to help, not judge
3. **Take Your Time**: No rush, develop your answer thoroughly
4. **Use Examples**: Real-world examples show understanding
5. **Structure Your Answer**: Introduction → Body → Conclusion
6. **Review Before Submit**: Read your chat history once more

---

## 📞 Support

If you encounter issues:
1. Check this guide first
2. Review `THEORY_QUESTIONS_IMPLEMENTATION.md` for details
3. Check Firestore console for data
4. Review Cloud Functions logs for errors
5. Test in different browsers (Chrome recommended)

---

## ✅ Success Indicators

You'll know it's working when:
- ✅ Browse page shows 1388 questions
- ✅ Filters work (subject/year)
- ✅ Split-view loads correctly
- ✅ AI responds to chat messages
- ✅ Submit button saves to Firestore
- ✅ Success dialog appears after submit

---

**Last Updated**: November 26, 2025  
**Status**: ✅ Ready for Testing  
**Next Review**: December 2025 (Debugging Period)
