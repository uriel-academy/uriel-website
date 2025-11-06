# Testing Guide - Grade Prediction System

## Quick Testing Checklist

### Prerequisites
✅ Firebase Auth configured
✅ Firestore initialized
✅ User logged in
✅ Question attempts data populated

---

## Test Data Setup

### 1. Create Sample Question Attempts

Run this in Firebase Console or via script:

```javascript
// Sample question attempt for testing
{
  questionId: "math_2024_q15",
  year: "2024",
  difficulty: "medium",
  timeSpentSeconds: 120,
  numberOfAttempts: 1,
  hintsUsed: 0,
  usedAIAssistance: false,
  isCorrect: true,
  topic: "Algebra",
  subject: "mathematics",
  attemptedAt: new Date()
}
```

### 2. Minimum Data Requirements

For meaningful predictions, ensure each subject has:
- **Minimum**: 10 question attempts
- **Recommended**: 50+ attempts
- **Ideal**: 100+ attempts with varied topics

### 3. Test Data Variations

Create attempts with:
- ✅ Different difficulties (easy, medium, hard)
- ✅ Various topics within subject
- ✅ Mix of correct/incorrect answers
- ✅ Different time ranges (recent and old)
- ✅ Some with AI assistance, some without

---

## Unit Tests

### Test Performance Data Models

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/models/performance_data.dart';

void main() {
  group('QuestionAttempt', () {
    test('calculates difficulty weight correctly', () {
      final hardAttempt = QuestionAttempt(
        questionId: 'q1',
        year: '2024',
        difficulty: 'hard',
        timeSpentSeconds: 120,
        numberOfAttempts: 1,
        hintsUsed: 0,
        usedAIAssistance: false,
        isCorrect: true,
        topic: 'Algebra',
        subject: 'mathematics',
        attemptedAt: DateTime.now(),
      );
      
      expect(hardAttempt.difficultyWeight, equals(1.2));
    });
    
    test('calculates recency factor correctly', () {
      final recentAttempt = QuestionAttempt(
        questionId: 'q1',
        year: '2024',
        difficulty: 'medium',
        timeSpentSeconds: 120,
        numberOfAttempts: 1,
        hintsUsed: 0,
        usedAIAssistance: false,
        isCorrect: true,
        topic: 'Algebra',
        subject: 'mathematics',
        attemptedAt: DateTime.now().subtract(Duration(days: 15)),
      );
      
      expect(recentAttempt.recencyFactor, equals(1.0));
    });
    
    test('calculates weighted score correctly', () {
      final attempt = QuestionAttempt(
        questionId: 'q1',
        year: '2024',
        difficulty: 'hard', // 1.2 weight
        timeSpentSeconds: 120,
        numberOfAttempts: 1,
        hintsUsed: 0,
        usedAIAssistance: false,
        isCorrect: true,
        topic: 'Algebra',
        subject: 'mathematics',
        attemptedAt: DateTime.now(), // 1.0 recency
      );
      
      expect(attempt.weightedScore, equals(1.2)); // 1.2 * 1.0
    });
  });
  
  group('GradePrediction', () {
    test('returns correct grade label', () {
      final prediction = GradePrediction(
        subject: 'mathematics',
        predictedGrade: 1,
        predictedScore: 90.0,
        confidence: 0.85,
        confidenceLevel: 'High',
        improvementTrend: 0.15,
        studyConsistency: 0.80,
        weakTopics: [],
        strongTopics: ['Algebra', 'Geometry'],
        recommendation: 'Keep up the great work!',
        calculatedAt: DateTime.now(),
      );
      
      expect(prediction.gradeLabel, equals('Highest Distinction'));
      expect(prediction.gradeColor, equals(Colors.green));
    });
    
    test('serializes to/from map correctly', () {
      final prediction = GradePrediction(
        subject: 'mathematics',
        predictedGrade: 3,
        predictedScore: 68.5,
        confidence: 0.72,
        confidenceLevel: 'Medium',
        improvementTrend: 0.12,
        studyConsistency: 0.65,
        weakTopics: ['Statistics', 'Probability'],
        strongTopics: ['Algebra'],
        recommendation: 'Focus on statistics',
        calculatedAt: DateTime.now(),
      );
      
      final map = prediction.toMap();
      final restored = GradePrediction.fromMap(map);
      
      expect(restored.subject, equals(prediction.subject));
      expect(restored.predictedGrade, equals(prediction.predictedGrade));
      expect(restored.predictedScore, equals(prediction.predictedScore));
    });
  });
}
```

---

## Integration Tests

### Test Prediction Service

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:uriel_mainapp/services/grade_prediction_service.dart';

void main() {
  group('GradePredictionService', () {
    late FakeFirebaseFirestore firestore;
    late GradePredictionService service;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = GradePredictionService();
      // Inject fake firestore if refactored for DI
    });
    
    test('predicts grade with sufficient data', () async {
      // Setup: Create 50 question attempts
      final userId = 'testUser123';
      for (int i = 0; i < 50; i++) {
        await firestore
            .collection('users')
            .doc(userId)
            .collection('questionAttempts')
            .add({
          'questionId': 'q$i',
          'year': '2024',
          'difficulty': i % 3 == 0 ? 'hard' : 'medium',
          'timeSpentSeconds': 100 + (i * 5),
          'numberOfAttempts': 1,
          'hintsUsed': 0,
          'usedAIAssistance': i % 5 == 0,
          'isCorrect': i % 2 == 0, // 50% accuracy
          'topic': 'Topic ${i % 5}',
          'subject': 'mathematics',
          'attemptedAt': DateTime.now().subtract(Duration(days: i)),
        });
      }
      
      final prediction = await service.predictGrade(
        userId: userId,
        subject: 'mathematics',
      );
      
      expect(prediction.predictedGrade, isA<int>());
      expect(prediction.predictedGrade, greaterThanOrEqualTo(1));
      expect(prediction.predictedGrade, lessThanOrEqualTo(9));
      expect(prediction.confidence, isA<double>());
    });
    
    test('returns default prediction with no data', () async {
      final prediction = await service.predictGrade(
        userId: 'newUser',
        subject: 'mathematics',
      );
      
      expect(prediction.predictedGrade, equals(9));
      expect(prediction.confidence, equals(0.0));
      expect(prediction.confidenceLevel, equals('Insufficient Data'));
    });
    
    test('caches prediction correctly', () async {
      final userId = 'testUser123';
      
      // First call - should calculate
      final prediction1 = await service.predictGrade(
        userId: userId,
        subject: 'mathematics',
      );
      
      // Second call - should return cached
      final prediction2 = await service.getCachedPrediction(
        userId: userId,
        subject: 'mathematics',
      );
      
      expect(prediction2, isNotNull);
      expect(prediction2!.calculatedAt, equals(prediction1.calculatedAt));
    });
  });
}
```

---

## Widget Tests

### Test Grade Prediction Card

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:uriel_mainapp/widgets/grade_prediction_card.dart';

void main() {
  group('GradePredictionCard', () {
    testWidgets('displays loading state initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradePredictionCard(userId: 'testUser'),
          ),
        ),
      );
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing your performance...'), findsOneWidget);
    });
    
    testWidgets('displays empty state for new user', (tester) async {
      // Mock service to return empty predictions
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradePredictionCard(userId: 'newUser'),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('Start practicing to see your predictions!'), findsOneWidget);
      expect(find.byIcon(Icons.quiz_outlined), findsOneWidget);
    });
    
    testWidgets('displays predictions when loaded', (tester) async {
      // Mock service with sample data
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradePredictionCard(userId: 'testUser'),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      expect(find.text('BECE Grade Predictions'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
    });
    
    testWidgets('switches subjects when chip tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradePredictionCard(userId: 'testUser'),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap ICT chip
      await tester.tap(find.text('ICT'));
      await tester.pumpAndSettle();
      
      // Verify subject changed
      // Add assertions based on mock data
    });
    
    testWidgets('refresh button triggers reload', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradePredictionCard(userId: 'testUser'),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Tap refresh
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      
      // Should show loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
```

---

## Manual Testing Checklist

### 1. Visual Testing

- [ ] Card displays correctly on desktop (>768px)
- [ ] Card displays correctly on tablet (480-768px)
- [ ] Card displays correctly on mobile (<480px)
- [ ] Gradient background renders properly
- [ ] Grade badges show correct colors
- [ ] Icons display correctly
- [ ] Text is readable on dark background

### 2. Functionality Testing

- [ ] Loading state appears on mount
- [ ] Predictions load after authentication
- [ ] Subject chips are selectable
- [ ] Selected subject shows detailed view
- [ ] Refresh button recalculates predictions
- [ ] Error state shows on failure
- [ ] Empty state shows for new users
- [ ] Compact mode displays top 3 subjects

### 3. Data Accuracy

- [ ] Grade mapping is correct (1=best, 9=fail)
- [ ] Weighted scores consider difficulty
- [ ] Recency factor favors recent attempts
- [ ] Improvement trend shows correctly
- [ ] Consistency calculation makes sense
- [ ] AI dependence penalty applies
- [ ] Confidence levels are reasonable

### 4. Performance Testing

- [ ] Card loads within 2 seconds
- [ ] Cached predictions load instantly
- [ ] Subject switching is smooth (<200ms)
- [ ] Refresh completes within 3 seconds
- [ ] No memory leaks on repeated loads
- [ ] Firestore queries are optimized

### 5. Edge Cases

- [ ] No data: Shows empty state
- [ ] 1-9 attempts: Shows low confidence
- [ ] 10-49 attempts: Shows medium confidence
- [ ] 50+ attempts: Shows high confidence
- [ ] All correct: Predicts grade 1
- [ ] All incorrect: Predicts grade 9
- [ ] Mixed performance: Reasonable grade
- [ ] Very old data: Lower recency factor

### 6. Error Handling

- [ ] Network error: Shows error state with retry
- [ ] Not logged in: Shows appropriate message
- [ ] Invalid user ID: Handles gracefully
- [ ] Missing Firestore data: Doesn't crash
- [ ] Malformed data: Defaults safely

### 7. Accessibility

- [ ] Screen reader announces grade
- [ ] Keyboard navigation works
- [ ] Touch targets are 44x44px minimum
- [ ] Color contrast meets WCAG AA
- [ ] Focus indicators are visible

---

## Test Data Scenarios

### Scenario 1: Excellent Student
```javascript
// 40 attempts, 95% accuracy, recent practice
{
  totalAttempts: 40,
  correctAttempts: 38,
  difficulties: { hard: 15, medium: 15, easy: 10 },
  timeRange: 'last 30 days',
  aiUsage: 'minimal',
  expectedGrade: 1-2,
  expectedConfidence: 'High'
}
```

### Scenario 2: Average Student
```javascript
// 30 attempts, 60% accuracy, inconsistent
{
  totalAttempts: 30,
  correctAttempts: 18,
  difficulties: { hard: 5, medium: 15, easy: 10 },
  timeRange: 'last 60 days',
  aiUsage: 'moderate',
  expectedGrade: 4-6,
  expectedConfidence: 'Medium'
}
```

### Scenario 3: Struggling Student
```javascript
// 20 attempts, 30% accuracy, declining
{
  totalAttempts: 20,
  correctAttempts: 6,
  difficulties: { hard: 2, medium: 8, easy: 10 },
  timeRange: 'last 90 days',
  aiUsage: 'heavy',
  expectedGrade: 7-9,
  expectedConfidence: 'Low'
}
```

### Scenario 4: Improving Student
```javascript
// Recent performance much better than old
{
  oldAttempts: { total: 20, correct: 6 }, // 30% (60-90 days ago)
  recentAttempts: { total: 20, correct: 16 }, // 80% (last 30 days)
  expectedTrend: '+50%',
  expectedGrade: 3-4,
  expectedRecommendation: 'Great improvement!'
}
```

---

## Debugging Tips

### Enable Verbose Logging

Add to `grade_prediction_service.dart`:
```dart
void _log(String message) {
  if (kDebugMode) {
    print('[GradePrediction] $message');
  }
}
```

### Inspect Firestore Queries

Use Firestore Console to verify:
1. Index exists: `questionAttempts` collection
2. Fields: `subject` (Ascending), `attemptedAt` (Descending)
3. Query matches: Check actual vs expected count

### Test Cache Behavior

Force cache refresh:
```dart
// Delete cached prediction
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('gradePredictions')
    .doc(subject)
    .delete();
```

### Validate Calculations

Add breakpoints at:
- Line where weighted average is calculated
- Improvement trend calculation
- Final score combination
- Grade mapping logic

---

## Performance Benchmarks

Expected performance metrics:

| Operation | Target | Maximum |
|-----------|--------|---------|
| Initial load (no cache) | <2s | 5s |
| Cached load | <500ms | 1s |
| Subject switch | <200ms | 500ms |
| Refresh | <2s | 5s |
| Batch prediction (6 subjects) | <5s | 10s |

---

## Continuous Testing

### Automated Tests
Run daily:
```bash
flutter test test/grade_prediction_test.dart
```

### Integration Tests
Run before deployment:
```bash
flutter test integration_test/
```

### Performance Tests
Monitor in production:
- Average load time
- Cache hit rate
- Prediction accuracy
- User engagement

---

## Bug Reporting Template

When reporting issues:

```markdown
## Bug Description
[Clear description of the issue]

## Steps to Reproduce
1. [First step]
2. [Second step]
3. [etc.]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Test Data
- User ID: [if applicable]
- Subject: [if applicable]
- Attempts count: [number]
- Prediction shown: [grade]

## Environment
- Device: [Desktop/Tablet/Mobile]
- Screen size: [width x height]
- Flutter version: [version]
- Firebase SDK: [version]

## Logs
[Include relevant console output]
```

---

## Success Criteria

The system passes testing when:
✅ All unit tests pass (100% coverage)
✅ All integration tests pass
✅ Widget tests cover key interactions
✅ Manual testing checklist complete
✅ Performance benchmarks met
✅ No critical bugs in production
✅ Prediction accuracy >80% (vs actual grades)

Happy Testing! 🎯
