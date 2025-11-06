# Question Attempt Tracking - Implementation Guide

## Overview
For the grade prediction system to work, we need to track every question attempt a student makes. This guide shows how to record attempts properly.

---

## Data Recording Service

Create `lib/services/question_attempt_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_data.dart';

class QuestionAttemptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a question attempt
  Future<void> recordAttempt({
    required String userId,
    required String questionId,
    required String year,
    required String difficulty,
    required int timeSpentSeconds,
    required bool isCorrect,
    required String topic,
    required String subject,
    int numberOfAttempts = 1,
    int hintsUsed = 0,
    bool usedAIAssistance = false,
  }) async {
    try {
      final attempt = QuestionAttempt(
        questionId: questionId,
        year: year,
        difficulty: difficulty,
        timeSpentSeconds: timeSpentSeconds,
        numberOfAttempts: numberOfAttempts,
        hintsUsed: hintsUsed,
        usedAIAssistance: usedAIAssistance,
        isCorrect: isCorrect,
        topic: topic,
        subject: subject,
        attemptedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('questionAttempts')
          .add(attempt.toMap());

      print('✅ Recorded attempt for question $questionId');
    } catch (e) {
      print('❌ Failed to record attempt: $e');
      // Consider retrying or storing locally for later sync
    }
  }

  /// Record multiple attempts (batch)
  Future<void> recordAttemptsBatch({
    required String userId,
    required List<QuestionAttempt> attempts,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final attempt in attempts) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('questionAttempts')
            .doc(); // Auto-generate ID

        batch.set(docRef, attempt.toMap());
      }

      await batch.commit();
      print('✅ Recorded ${attempts.length} attempts in batch');
    } catch (e) {
      print('❌ Failed to record batch: $e');
    }
  }

  /// Update an attempt if student retries
  Future<void> updateAttempt({
    required String userId,
    required String attemptId,
    required bool isCorrect,
    required int timeSpentSeconds,
    int? additionalHints,
    bool? usedAI,
  }) async {
    try {
      final updates = {
        'isCorrect': isCorrect,
        'timeSpentSeconds': timeSpentSeconds,
        'numberOfAttempts': FieldValue.increment(1),
      };

      if (additionalHints != null) {
        updates['hintsUsed'] = FieldValue.increment(additionalHints);
      }

      if (usedAI != null && usedAI) {
        updates['usedAIAssistance'] = true;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('questionAttempts')
          .doc(attemptId)
          .update(updates);

      print('✅ Updated attempt $attemptId');
    } catch (e) {
      print('❌ Failed to update attempt: $e');
    }
  }

  /// Get attempt history for a question
  Future<List<QuestionAttempt>> getAttemptHistory({
    required String userId,
    required String questionId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('questionAttempts')
          .where('questionId', isEqualTo: questionId)
          .orderBy('attemptedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => QuestionAttempt.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Failed to get attempt history: $e');
      return [];
    }
  }
}
```

---

## Integration Points

### 1. Quiz/Practice Question Screen

When student answers a question:

```dart
class QuizQuestionWidget extends StatefulWidget {
  final Question question;
  final String subject;
  
  @override
  State<QuizQuestionWidget> createState() => _QuizQuestionWidgetState();
}

class _QuizQuestionWidgetState extends State<QuizQuestionWidget> {
  final QuestionAttemptService _attemptService = QuestionAttemptService();
  DateTime? _startTime;
  int _hintsUsed = 0;
  bool _usedAI = false;
  
  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }
  
  Future<void> _submitAnswer(String selectedAnswer) async {
    final timeSpent = DateTime.now().difference(_startTime!).inSeconds;
    final isCorrect = selectedAnswer == widget.question.correctAnswer;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (userId == null) return;
    
    // Record the attempt
    await _attemptService.recordAttempt(
      userId: userId,
      questionId: widget.question.id,
      year: widget.question.year,
      difficulty: widget.question.difficulty ?? 'medium',
      timeSpentSeconds: timeSpent,
      isCorrect: isCorrect,
      topic: widget.question.topic,
      subject: widget.subject,
      hintsUsed: _hintsUsed,
      usedAIAssistance: _usedAI,
    );
    
    // Show feedback and move to next question
    _showFeedback(isCorrect);
  }
  
  void _onHintRequested() {
    setState(() => _hintsUsed++);
  }
  
  void _onAIHelpUsed() {
    setState(() => _usedAI = true);
  }
  
  // ... rest of widget implementation
}
```

### 2. Past Questions Practice

```dart
class PastQuestionsScreen extends StatefulWidget {
  final String subject;
  final String year;
  
  @override
  State<PastQuestionsScreen> createState() => _PastQuestionsScreenState();
}

class _PastQuestionsScreenState extends State<PastQuestionsScreen> {
  final QuestionAttemptService _attemptService = QuestionAttemptService();
  final Map<String, DateTime> _questionStartTimes = {};
  final Map<String, int> _questionHints = {};
  
  Future<void> _recordQuestionAttempt({
    required String questionId,
    required String answer,
    required String correctAnswer,
    required String topic,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final startTime = _questionStartTimes[questionId];
    if (startTime == null) return;
    
    final timeSpent = DateTime.now().difference(startTime).inSeconds;
    final isCorrect = answer == correctAnswer;
    
    await _attemptService.recordAttempt(
      userId: userId,
      questionId: questionId,
      year: widget.year,
      difficulty: _inferDifficulty(questionId), // Implement based on your system
      timeSpentSeconds: timeSpent,
      isCorrect: isCorrect,
      topic: topic,
      subject: widget.subject,
      hintsUsed: _questionHints[questionId] ?? 0,
    );
  }
  
  String _inferDifficulty(String questionId) {
    // Implement logic to determine difficulty
    // Could be from question metadata or inferred from question number
    // e.g., questions 1-20 = easy, 21-35 = medium, 36-40 = hard
    return 'medium'; // Default
  }
  
  // ... rest of implementation
}
```

### 3. Mock Exam Completion

```dart
class MockExamResultsScreen extends StatefulWidget {
  final List<QuestionResult> results;
  final String subject;
  final String examYear;
  
  @override
  State<MockExamResultsScreen> createState() => _MockExamResultsScreenState();
}

class _MockExamResultsScreenState extends State<MockExamResultsScreen> {
  final QuestionAttemptService _attemptService = QuestionAttemptService();
  
  @override
  void initState() {
    super.initState();
    _recordAllAttempts();
  }
  
  Future<void> _recordAllAttempts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final attempts = widget.results.map((result) {
      return QuestionAttempt(
        questionId: result.questionId,
        year: widget.examYear,
        difficulty: result.difficulty,
        timeSpentSeconds: result.timeSpent,
        numberOfAttempts: 1,
        hintsUsed: 0,
        usedAIAssistance: false,
        isCorrect: result.isCorrect,
        topic: result.topic,
        subject: widget.subject,
        attemptedAt: DateTime.now(),
      );
    }).toList();
    
    // Use batch recording for efficiency
    await _attemptService.recordAttemptsBatch(
      userId: userId,
      attempts: attempts,
    );
  }
  
  // ... rest of implementation
}
```

---

## Question Metadata Requirements

Ensure each question has these properties:

```dart
class Question {
  final String id;
  final String year;
  final String topic;
  final String? difficulty; // 'easy', 'medium', 'hard'
  final String question;
  final List<String> options;
  final String correctAnswer;
  
  // ... other properties
}
```

### If difficulty is missing, infer it:

```dart
String inferDifficulty({
  required int questionNumber,
  required String subject,
}) {
  // Strategy 1: Based on question number
  if (questionNumber <= 15) return 'easy';
  if (questionNumber <= 30) return 'medium';
  return 'hard';
  
  // Strategy 2: Based on historical accuracy (if available)
  // Strategy 3: Based on teacher ratings (if available)
}
```

---

## Topic Mapping

Ensure consistent topic names across questions:

```dart
// Example topic mapping for Mathematics
const Map<String, String> mathTopics = {
  'arithmetic': 'Arithmetic',
  'algebra': 'Algebra',
  'geometry': 'Geometry',
  'statistics': 'Statistics',
  'probability': 'Probability',
  'measurement': 'Measurement',
  'graphs': 'Graphs and Functions',
  'sets': 'Sets and Logic',
};

// Use standardized topic names
String standardizeTopic(String rawTopic, String subject) {
  switch (subject) {
    case 'mathematics':
      return mathTopics[rawTopic.toLowerCase()] ?? rawTopic;
    case 'english':
      return englishTopics[rawTopic.toLowerCase()] ?? rawTopic;
    // ... other subjects
    default:
      return rawTopic;
  }
}
```

---

## Tracking AI Assistance

### When to mark `usedAIAssistance = true`:

1. **AI Chat Help**: Student asks AI for explanation during question
2. **Hint from AI**: AI provides hints or clues
3. **AI Solution**: Student views AI-generated solution before answering
4. **AI Explanation**: Student reads AI explanation of similar question

### Example implementation:

```dart
class QuestionScreen extends StatefulWidget {
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  bool _usedAI = false;
  
  void _showAIHelp() {
    setState(() => _usedAI = true);
    
    // Show AI assistance dialog
    showDialog(
      context: context,
      builder: (context) => AIHelpDialog(
        question: widget.question,
        onDismiss: () {
          // AI help was used, flag is already set
        },
      ),
    );
  }
  
  // ... rest of implementation
}
```

---

## Time Tracking Best Practices

### 1. Accurate Time Measurement

```dart
class QuestionTimer {
  DateTime? _startTime;
  int _pausedDuration = 0;
  DateTime? _pausedAt;
  
  void start() {
    _startTime = DateTime.now();
  }
  
  void pause() {
    if (_startTime != null && _pausedAt == null) {
      _pausedAt = DateTime.now();
    }
  }
  
  void resume() {
    if (_pausedAt != null) {
      _pausedDuration += DateTime.now().difference(_pausedAt!).inSeconds;
      _pausedAt = null;
    }
  }
  
  int getTimeSpent() {
    if (_startTime == null) return 0;
    
    final totalTime = DateTime.now().difference(_startTime!).inSeconds;
    return totalTime - _pausedDuration;
  }
}
```

### 2. Handle App Backgrounding

```dart
class QuestionScreen extends StatefulWidget {
  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> 
    with WidgetsBindingObserver {
  final QuestionTimer _timer = QuestionTimer();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer.start();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _timer.pause();
        break;
      case AppLifecycleState.resumed:
        _timer.resume();
        break;
      default:
        break;
    }
  }
  
  // ... rest of implementation
}
```

---

## Offline Support

### Queue attempts when offline:

```dart
class OfflineQuestionAttemptService {
  static const String _queueKey = 'pending_attempts';
  
  Future<void> recordAttemptOffline(QuestionAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    
    queue.add(jsonEncode(attempt.toMap()));
    await prefs.setStringList(_queueKey, queue);
  }
  
  Future<void> syncPendingAttempts(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    
    if (queue.isEmpty) return;
    
    final attempts = queue
        .map((json) => QuestionAttempt.fromMap(jsonDecode(json)))
        .toList();
    
    await QuestionAttemptService().recordAttemptsBatch(
      userId: userId,
      attempts: attempts,
    );
    
    // Clear queue after successful sync
    await prefs.remove(_queueKey);
  }
}
```

---

## Privacy & Data Protection

### 1. User Consent

```dart
Future<bool> getUserConsentForTracking() async {
  final prefs = await SharedPreferences.getInstance();
  final hasConsented = prefs.getBool('tracking_consent') ?? false;
  
  if (!hasConsented) {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Performance Tracking'),
        content: Text(
          'We track your question attempts to provide personalized grade '
          'predictions and learning insights. Your data is private and '
          'never shared with third parties.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Accept'),
          ),
        ],
      ),
    );
    
    if (consent == true) {
      await prefs.setBool('tracking_consent', true);
      return true;
    }
    return false;
  }
  
  return true;
}
```

### 2. Data Anonymization

```dart
// Never store personally identifiable information in attempts
// Only use user ID for linking data

// ✅ Good
await _attemptService.recordAttempt(
  userId: userId, // Just the ID
  questionId: questionId,
  // ... other fields
);

// ❌ Bad
await _attemptService.recordAttempt(
  userId: userId,
  userName: 'John Doe', // Don't include
  userEmail: 'john@example.com', // Don't include
  // ...
);
```

---

## Firestore Security Rules

Add to `firestore.rules`:

```javascript
match /users/{userId}/questionAttempts/{attemptId} {
  // Users can only read/write their own attempts
  allow read, write: if request.auth != null && request.auth.uid == userId;
  
  // Validate data structure
  allow create: if request.resource.data.keys().hasAll([
    'questionId', 'year', 'difficulty', 'timeSpentSeconds',
    'numberOfAttempts', 'hintsUsed', 'usedAIAssistance',
    'isCorrect', 'topic', 'subject', 'attemptedAt'
  ]);
}
```

---

## Monitoring & Analytics

Track these metrics:

```dart
class AttemptAnalytics {
  static Future<void> logAttemptRecorded({
    required String subject,
    required bool isCorrect,
    required int timeSpent,
  }) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'question_attempt',
      parameters: {
        'subject': subject,
        'is_correct': isCorrect,
        'time_spent': timeSpent,
      },
    );
  }
  
  static Future<void> logBatchSync({
    required int attemptCount,
  }) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'attempts_synced',
      parameters: {
        'count': attemptCount,
      },
    );
  }
}
```

---

## Migration Script

For existing users without attempt data:

```javascript
// Firebase Cloud Function to backfill data if you have historical quiz results
exports.migrateQuizResultsToAttempts = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  
  // Get all users
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    
    // Get quiz results (adjust based on your structure)
    const quizResults = await db
      .collection('users')
      .doc(userId)
      .collection('quizResults')
      .get();
    
    const batch = db.batch();
    let count = 0;
    
    for (const resultDoc of quizResults.docs) {
      const result = resultDoc.data();
      
      // Convert to question attempt format
      const attemptRef = db
        .collection('users')
        .doc(userId)
        .collection('questionAttempts')
        .doc();
      
      batch.set(attemptRef, {
        questionId: result.questionId,
        year: result.year || '2024',
        difficulty: result.difficulty || 'medium',
        timeSpentSeconds: result.timeSpent || 60,
        numberOfAttempts: 1,
        hintsUsed: result.hintsUsed || 0,
        usedAIAssistance: result.usedAI || false,
        isCorrect: result.isCorrect,
        topic: result.topic || 'General',
        subject: result.subject,
        attemptedAt: result.completedAt || admin.firestore.Timestamp.now(),
      });
      
      count++;
      
      // Commit every 500 operations
      if (count % 500 === 0) {
        await batch.commit();
      }
    }
    
    // Commit remaining
    if (count % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`Migrated ${count} attempts for user ${userId}`);
  }
  
  res.json({ success: true, message: 'Migration complete' });
});
```

---

## Testing

Verify tracking is working:

```dart
// Test recording an attempt
void testRecordAttempt() async {
  final service = QuestionAttemptService();
  
  await service.recordAttempt(
    userId: 'testUser123',
    questionId: 'math_2024_q1',
    year: '2024',
    difficulty: 'medium',
    timeSpentSeconds: 90,
    isCorrect: true,
    topic: 'Algebra',
    subject: 'mathematics',
  );
  
  print('Test attempt recorded - check Firestore');
}
```

---

## Summary

**Key Points:**
1. ✅ Record every question attempt immediately
2. ✅ Include all required fields (difficulty, topic, time, etc.)
3. ✅ Track AI assistance usage accurately
4. ✅ Measure time spent properly (pause when backgrounded)
5. ✅ Support offline queueing and sync
6. ✅ Respect user privacy and consent
7. ✅ Use batch operations for multiple attempts
8. ✅ Standardize topic names across subjects
9. ✅ Secure with proper Firestore rules
10. ✅ Monitor and validate data quality

With proper attempt tracking, the grade prediction system will have rich data to generate accurate, personalized forecasts! 🎯
