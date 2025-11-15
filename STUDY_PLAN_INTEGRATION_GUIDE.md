# Study Plan Progress Tracking Integration Guide
## How to Wire Up Progress Tracking to Features

### Overview
The `StudyPlanProgressService` has been created to automatically track student activity and update their weekly study goals. This guide shows you exactly where to add tracking calls in your existing code.

---

## 📍 Integration Points

### 1. Past Questions Feature
**Files to Modify:**
- `lib/screens/quiz_taker_page.dart`
- `lib/screens/past_questions_search_page.dart`
- Any other quiz/question completion screens

**Where to Add:**
When a quiz is completed (user finishes all questions or submits quiz)

**Code to Add:**
```dart
// At the top of the file
import '../services/study_plan_progress_service.dart';

// In the method that handles quiz completion (usually _submitQuiz or similar)
Future<void> _submitQuiz() async {
  // ... existing quiz submission code ...
  
  // Track progress for study plan
  await StudyPlanProgressService().trackPastQuestionCompleted();
  
  // ... rest of submission code (navigation, etc.) ...
}
```

**Example Location in quiz_taker_page.dart:**
Look for methods like:
- `_submitQuiz()`
- `_finishQuiz()`
- `_showResults()`

Add the tracking call AFTER the quiz is successfully submitted but BEFORE navigation.

---

### 2. Textbooks/EPUB Reader
**Files to Modify:**
- `lib/screens/textbooks.dart`
- `lib/screens/epub_reader.dart` (if exists)
- Any chapter reading completion screens

**Where to Add:**
When a user finishes reading a chapter or completes a reading session

**Code to Add:**
```dart
// At the top of the file
import '../services/study_plan_progress_service.dart';

// When chapter is marked as complete
Future<void> _markChapterComplete() async {
  // ... existing chapter completion code ...
  
  // Track progress for study plan
  await StudyPlanProgressService().trackTextbookChapterCompleted();
  
  // ... update UI, etc. ...
}
```

**Suggested Trigger Points:**
- User clicks "Mark as Complete" button
- User reaches last page of chapter and clicks "Next Chapter"
- User closes book after reading for X minutes (if time-tracking exists)

---

### 3. AI Tools (Uri/ChatGPT-like Page)
**Files to Modify:**
- `lib/screens/uri_page.dart`
- `lib/screens/ai_tools.dart`
- Any AI chat/assistant screens

**Where to Add:**
When a user completes an AI study session

**Code to Add:**
```dart
// At the top of the file
import '../services/study_plan_progress_service.dart';

// Track after meaningful AI interaction
Future<void> _handleAIResponse() async {
  // ... existing AI response handling ...
  
  // Track progress (only after substantial interaction, e.g., 3+ messages exchanged)
  if (_messageCount >= 3) {
    await StudyPlanProgressService().trackAISessionCompleted();
    _messageCount = 0; // Reset counter
  }
  
  // ... rest of code ...
}
```

**Suggested Trigger Points:**
- After user has exchanged 3+ messages with AI
- When user clicks "Generate Study Plan" or "Create Quiz"
- When user completes an AI-generated quiz or exercise

---

### 4. Trivia Games
**Files to Modify:**
- Look for trivia game screens (check `lib/screens/` for trivia-related files)
- Any gamification or quiz game screens

**Where to Add:**
When a trivia game/session is completed

**Code to Add:**
```dart
// At the top of the file
import '../services/study_plan_progress_service.dart';

// When trivia game ends
Future<void> _endTriviaGame() async {
  // ... calculate score, show results ...
  
  // Track progress for study plan
  await StudyPlanProgressService().trackTriviaGameCompleted();
  
  // ... show results screen, update leaderboard, etc. ...
}
```

**Suggested Trigger Points:**
- When trivia game timer runs out
- When user answers all trivia questions
- When user exits trivia game (if min. questions answered)

---

## 🔧 Step-by-Step Integration Example

### Example: Adding to Quiz Taker Page

1. **Open the file:**
   ```
   lib/screens/quiz_taker_page.dart
   ```

2. **Add import at the top:**
   ```dart
   import '../services/study_plan_progress_service.dart';
   ```

3. **Find the quiz completion method:**
   Look for something like:
   ```dart
   void _submitQuiz() {
     // Calculate score
     int correctAnswers = _calculateScore();
     
     // Save result to Firestore
     _saveQuizResult(correctAnswers);
     
     // Navigate to results
     Navigator.push(...);
   }
   ```

4. **Add tracking call:**
   ```dart
   void _submitQuiz() async {  // Make sure method is async
     // Calculate score
     int correctAnswers = _calculateScore();
     
     // Save result to Firestore
     await _saveQuizResult(correctAnswers);
     
     // 🎯 NEW: Track progress for study plan
     await StudyPlanProgressService().trackPastQuestionCompleted();
     
     // Navigate to results
     Navigator.push(...);
   }
   ```

---

## 🎨 UI Enhancements (Optional)

### Show Goal Achievement Notification
When a user reaches a weekly goal, you can show a celebration:

```dart
import '../services/study_plan_progress_service.dart';

Future<void> _completeActivity() async {
  // ... complete the activity ...
  
  // Track progress
  await StudyPlanProgressService().trackPastQuestionCompleted();
  
  // Check if goal was just reached
  final goalsReached = await StudyPlanProgressService().checkGoalsReached();
  
  if (goalsReached['past_questions'] == true) {
    // Show celebration dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 30),
            SizedBox(width: 12),
            Text('Goal Achieved! 🎉'),
          ],
        ),
        content: Text(
          'Congratulations! You\'ve completed your weekly past questions goal!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Awesome!'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📊 Testing Your Integration

### 1. Create a Test Study Plan
```
1. Sign in to app
2. Navigate to student dashboard
3. Click "Create My Study Plan"
4. Fill out form with small goals (e.g., 1 past question, 1 trivia game)
5. Submit plan
```

### 2. Test Each Feature
```
For Past Questions:
  1. Complete a quiz
  2. Go back to dashboard
  3. Verify "Past Questions" progress bar increased (should show 1/1)

For Trivia:
  1. Play a trivia game
  2. Complete it
  3. Check dashboard - "Trivia Games" should be 1/1

Repeat for Textbooks and AI Tools
```

### 3. Verify in Firestore
```
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to: users/{userId}/study_plan/current
4. Check the "progress" field:
   {
     past_questions: 1,
     textbook_chapters: 0,
     ai_sessions: 0,
     trivia_games: 1
   }
```

---

## 🐛 Troubleshooting

### Progress not updating?

**Check 1: Import statement**
```dart
// Make sure this is at the top of your file
import '../services/study_plan_progress_service.dart';
```

**Check 2: Async/await**
```dart
// Method must be async
Future<void> _myMethod() async {
  await StudyPlanProgressService().trackPastQuestionCompleted();
}
```

**Check 3: User is authenticated**
```dart
// Service automatically checks this, but verify user is signed in
final user = FirebaseAuth.instance.currentUser;
print('User: ${user?.uid}'); // Should not be null
```

**Check 4: Study plan exists**
```dart
// User must have created a study plan first
// The service will silently skip if no plan exists (by design)
```

### Firestore permissions error?

Make sure your `firestore.rules` includes:
```javascript
match /users/{userId}/study_plan/{planId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Then deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## 📅 Weekly Reset (Cloud Function)

### Create Cloud Function to Reset Progress Every Monday

**File:** `functions/src/index.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const resetWeeklyStudyGoals = functions.pubsub
  .schedule('0 0 * * MON')
  .timeZone('Africa/Accra')
  .onRun(async (context) => {
    try {
      console.log('Starting weekly study goals reset...');
      
      // Get all study plans
      const plansSnapshot = await admin.firestore()
        .collectionGroup('study_plan')
        .where('weekly_goals', '!=', null)
        .get();
      
      console.log(`Found ${plansSnapshot.size} study plans to reset`);
      
      // Reset progress in batches
      const batch = admin.firestore().batch();
      let count = 0;
      
      plansSnapshot.forEach(doc => {
        batch.update(doc.ref, {
          'progress.past_questions': 0,
          'progress.textbook_chapters': 0,
          'progress.ai_sessions': 0,
          'progress.trivia_games': 0,
          'last_reset': admin.firestore.FieldValue.serverTimestamp(),
        });
        count++;
      });
      
      await batch.commit();
      console.log(`Successfully reset ${count} study plans`);
      
      return null;
    } catch (error) {
      console.error('Error resetting weekly goals:', error);
      throw error;
    }
  });
```

**Deploy the function:**
```bash
cd functions
npm run build
firebase deploy --only functions:resetWeeklyStudyGoals
```

**Verify it's scheduled:**
```bash
firebase functions:log --only resetWeeklyStudyGoals
```

---

## ✅ Integration Checklist

- [ ] Add import statement to quiz completion file
- [ ] Add tracking call after quiz submission
- [ ] Add import statement to textbook reader
- [ ] Add tracking call after chapter completion
- [ ] Add import statement to AI tools page
- [ ] Add tracking call after AI session
- [ ] Add import statement to trivia game
- [ ] Add tracking call after game completion
- [ ] Test each feature with a real account
- [ ] Verify progress updates in Firestore
- [ ] Deploy Firestore security rules
- [ ] Create and deploy weekly reset Cloud Function
- [ ] Test weekly reset manually (or wait for Monday)

---

## 🎯 Expected User Flow

1. **New User:**
   - Sees onboarding card on dashboard
   - Creates study plan with goals
   - Completes activities throughout the week
   - Progress bars update automatically
   - Reaches goals → sees celebration message

2. **Returning User:**
   - Sees current week's progress
   - Continues completing activities
   - Monday arrives → progress resets to 0
   - New week begins with fresh goals

---

## 📞 Support

If you encounter issues:
1. Check console logs for errors
2. Verify Firestore security rules
3. Confirm user authentication status
4. Check network connectivity
5. Review Firebase Console for quota limits

---

*Last Updated: November 15, 2025*
*Integration Status: Service Created, Awaiting Feature Integration*
