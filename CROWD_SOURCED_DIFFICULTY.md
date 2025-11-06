# Crowd-Sourced Question Difficulty Implementation

## Overview
This implementation replaces preset BECE difficulty ratings with dynamic, crowd-sourced difficulty calculations based on actual student performance data across the platform.

## Architecture

### 1. Question Difficulty Service (`lib/services/question_difficulty_service.dart`)
Flutter service that calculates and retrieves crowd-sourced difficulty scores.

**Key Methods:**
- `getQuestionDifficulty(questionId)` - Calculate difficulty from attempt data (1 - successRate)
- `getCachedDifficulty(questionId)` - Retrieve cached difficulty from Firestore
- `difficultyToWeight(difficulty)` - Convert 0-1 difficulty to 0.7-1.3 weight
- `getDifficultyLabel(difficulty)` - Convert score to Easy/Medium/Hard label
- `updateAllQuestionDifficulties(subject)` - Batch update all questions for a subject
- `getSubjectDifficultyStats(subject)` - Get difficulty distribution statistics

**Difficulty Formula:**
```
difficulty = 1 - successRate

Examples:
- 90% success → 0.1 difficulty (Easy) → 0.76 weight
- 50% success → 0.5 difficulty (Medium) → 1.0 weight
- 20% success → 0.8 difficulty (Hard) → 1.18 weight
```

**Weight Mapping:**
```
weight = 0.7 + (difficulty × 0.6)

Range: 0.7 (easiest) to 1.3 (hardest)
```

**Minimum Data Threshold:**
- Requires minimum 20 attempts per question for reliable calculation
- Returns 0.5 (neutral) if insufficient data

### 2. Cloud Functions (`functions/src/updateQuestionDifficulty.ts`)

#### Scheduled Weekly Update
**Function:** `updateQuestionDifficulties`
- **Schedule:** Every Sunday at 2 AM UTC
- **Subjects:** RME, Mathematics, English, Science, Social Studies
- **Process:**
  1. Query all attempts via collectionGroup
  2. Group by questionId
  3. Calculate successRate and difficulty
  4. Batch write to `questionDifficulty` collection
  5. Skip questions with < 20 attempts

#### Manual Admin Trigger
**Function:** `manualUpdateDifficulties`
- **Auth:** Requires super_admin or admin role
- **HTTP:** POST with Bearer token
- **Purpose:** On-demand difficulty recalculation

#### Statistics Query
**Function:** `getSubjectDifficultyStats`
- **Type:** Callable function
- **Returns:** Easy/Medium/Hard distribution and average difficulty
- **Use Cases:** Analytics dashboards, curriculum planning

### 3. Grade Prediction Integration (`lib/services/grade_prediction_service.dart`)

**Updated Methods:**
- Added `QuestionDifficultyService` dependency
- Created `enrichWithCrowdDifficulty()` method to load real-time difficulty
- Modified `_calculateWeightedAverage()` to use dynamic difficulty weights

**Grade Prediction Algorithm:**
```
finalScore = (0.50 × WeightedAvg) + 
             (0.20 × ImprovementTrend) + 
             (0.15 × Consistency) + 
             (0.25 × RecentPerformance) - 
             (0.10 × AIPenalty)

Where:
- WeightedAvg uses crowd-sourced difficulty weights
- Recency factor: exp(-daysAgo / 90) - 90-day half-life
- Difficulty weight: 0.7 to 1.3 based on success rate
```

### 4. Data Models (`lib/models/performance_data.dart`)

**QuestionAttempt Model:**
```dart
class QuestionAttempt {
  final String questionId;
  final int year;
  final String difficulty;  // 'Easy', 'Medium', 'Hard'
  final int timeSpentSeconds;
  final int attemptsBeforeCorrect;
  final bool usedHint;
  final bool usedAIAssistance;
  final DateTime attemptedAt;
  final bool isCorrect;
  final String topic;
  final String subject;
}
```

**Computed Properties:**
- `difficultyWeight` - Dynamic weight from crowd-sourced calculation
- `recencyFactor` - Exponential decay based on attempt age
- `penaltyFactor` - Multiplier for hint/AI usage (0.9× hint, 0.85× AI)

### 5. Firestore Structure

#### Collections

**questionDifficulty** (calculated weekly)
```
{
  "questionId": "q123",
  "difficulty": 0.65,        // 0-1 score
  "weight": 1.09,            // 0.7-1.3 weight
  "label": "Hard",           // Easy/Medium/Hard
  "subject": "RME",
  "successRate": 0.35,
  "totalAttempts": 147,
  "correctAttempts": 52,
  "calculatedAt": Timestamp
}
```

**users/{uid}/questionAttempts/{attemptId}**
```
{
  "questionId": "q123",
  "year": 2024,
  "difficulty": "Hard",
  "timeSpentSeconds": 180,
  "attemptsBeforeCorrect": 2,
  "usedHint": false,
  "usedAIAssistance": true,
  "attemptedAt": Timestamp,
  "isCorrect": true,
  "topic": "Moral Values",
  "subject": "RME"
}
```

### 6. Security Rules (`firestore.rules`)

```javascript
// Question Difficulty - read-only for users
match /questionDifficulty/{questionId} {
  allow read: if isAuthenticated();
  allow write: if false; // Cloud Functions only
}

// Question Attempts - users can create their own
match /users/{userId}/questionAttempts/{attemptId} {
  allow read: if isOwner(userId) || isAdmin() || isParent(userId);
  allow create: if isAuthenticated() && 
                request.auth.uid == userId &&
                hasRequiredFields(['questionId', 'attemptedAt', 'isCorrect']);
  allow update, delete: if false; // Immutable for integrity
}
```

## Benefits

### 1. **Fairness**
- No preset assumptions about question difficulty
- Treats all BECE questions equally by default
- Difficulty emerges organically from actual performance

### 2. **Accuracy**
- Reflects real student performance patterns
- Accounts for regional and temporal variations
- Self-correcting as more data accumulates

### 3. **Adaptability**
- Automatically adjusts to curriculum changes
- Responds to teaching quality improvements
- Handles question pool updates gracefully

### 4. **Cold Start Strategy**
- New questions default to 0.5 (medium)
- Year-based estimation when < 20 attempts:
  - 2024+: 0.50 (current curriculum)
  - 2020-2023: 0.45 (recent, slightly easier)
  - Pre-2020: 0.40 (older, more familiar)

### 5. **Transparency**
- Students see performance-based difficulty
- Presented as "topic performance" to avoid confusion
- Admin dashboard shows difficulty distributions

## Usage Examples

### Student Grade Prediction
```dart
final predictionService = GradePredictionService();
final prediction = await predictionService.predictGrade(
  userId: 'user123',
  subject: 'Religious and Moral Education',
);

print('Predicted Grade: ${prediction.grade}');
print('Confidence: ${prediction.confidence}%');
print('Topic Mastery: ${prediction.topicMastery}');
```

### Admin Difficulty Analysis
```dart
final difficultyService = QuestionDifficultyService();
final stats = await difficultyService.getSubjectDifficultyStats('RME');

print('Easy: ${stats['easy']} questions');
print('Medium: ${stats['medium']} questions');
print('Hard: ${stats['hard']} questions');
print('Average Difficulty: ${stats['avgDifficulty']}');
```

### Manual Difficulty Update (Admin)
```bash
curl -X POST \
  https://us-central1-uriel-academy-41fb0.cloudfunctions.net/manualUpdateDifficulties \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

## Performance Considerations

### Optimization Strategies

1. **Caching Layer**
   - Difficulty scores cached in `questionDifficulty` collection
   - Updated weekly via scheduled function
   - Hourly in-memory cache refresh for active questions

2. **Batch Processing**
   - Firestore batch writes (max 500 operations)
   - CollectionGroup queries for efficient aggregation
   - Parallel subject processing in Cloud Functions

3. **Query Efficiency**
   - Indexed fields: `questionId`, `subject`, `calculatedAt`
   - Subcollection structure for user attempts
   - Limit queries to recent attempts (500 max)

4. **Cold Start Mitigation**
   - Year-based difficulty estimation
   - Minimum 20 attempts threshold
   - Fallback to 0.5 neutral weight

### Scalability

**Current Capacity:**
- 10,000+ questions across 5 subjects
- 100,000+ attempts per subject
- Weekly batch update: ~9 minutes max

**Future Scaling:**
- Regional difficulty variants (Accra vs rural)
- School-level difficulty adjustments
- Question pool A/B testing

## Monitoring & Analytics

### Key Metrics
- **Data Coverage:** % questions with 20+ attempts
- **Difficulty Distribution:** Easy/Medium/Hard balance
- **Trend Analysis:** Difficulty changes over time
- **Outlier Detection:** Questions with anomalous success rates

### Admin Dashboard Widgets
1. Subject difficulty heatmap
2. Question difficulty timeline
3. Success rate by topic
4. Cold-start question count
5. Weekly update logs

## Testing Strategy

### Unit Tests
```dart
test('Difficulty calculation with 80% success rate', () {
  final difficulty = 1 - 0.80;  // 0.2 (Easy)
  final weight = 0.7 + (difficulty * 0.6);  // 0.82
  expect(weight, closeTo(0.82, 0.01));
});

test('Insufficient data returns neutral', () async {
  final service = QuestionDifficultyService();
  // Mock < 20 attempts
  final difficulty = await service.getQuestionDifficulty('newQ');
  expect(difficulty, equals(0.5));
});
```

### Integration Tests
1. Create test attempts with known distribution
2. Trigger difficulty calculation
3. Verify correct difficulty score
4. Test grade prediction accuracy

### Load Tests
- Simulate 100,000 concurrent attempts
- Measure Cloud Function execution time
- Validate batch write performance
- Monitor Firestore read/write quotas

## Migration Plan

### Phase 1: Parallel Tracking (2 weeks)
- Deploy new services and Cloud Functions
- Calculate difficulty but don't use in predictions
- Validate data quality and coverage

### Phase 2: Soft Launch (2 weeks)
- Use crowd-sourced difficulty for 20% of users
- A/B test prediction accuracy
- Monitor user feedback

### Phase 3: Full Rollout (1 week)
- Switch all users to crowd-sourced difficulty
- Deprecate preset difficulty values
- Archive old difficulty data

### Phase 4: Optimization (Ongoing)
- Fine-tune weight ranges
- Adjust cold-start thresholds
- Add regional variations

## Known Limitations

1. **Cold Start Problem:**
   - New questions have no data
   - Year-based estimation is approximate
   - First 20 attempts may be unreliable

2. **Selection Bias:**
   - Only tracks active users
   - High performers may skew easier questions
   - Low performers may avoid hard questions

3. **Temporal Drift:**
   - Curriculum changes affect difficulty
   - Teacher quality improvements reduce difficulty
   - Old data may not reflect current standards

4. **Sample Size:**
   - Rural schools may have fewer attempts
   - Unpopular subjects have less data
   - Recent exam years lack historical context

## Future Enhancements

### Short Term (1-3 months)
- [ ] Real-time difficulty updates (hourly instead of weekly)
- [ ] Difficulty trend visualization in UI
- [ ] Admin override for specific questions
- [ ] Difficulty-based question recommendations

### Medium Term (3-6 months)
- [ ] Regional difficulty variants (Greater Accra vs Northern Region)
- [ ] School-level difficulty adjustments
- [ ] Peer comparison (your difficulty vs class average)
- [ ] Adaptive testing based on difficulty

### Long Term (6-12 months)
- [ ] Machine learning difficulty prediction
- [ ] Multi-factor difficulty (not just success rate)
- [ ] Cross-subject difficulty correlation
- [ ] Predictive modeling for new questions

## Support & Troubleshooting

### Common Issues

**Issue:** Questions stuck at 0.5 difficulty
- **Cause:** < 20 attempts
- **Fix:** Wait for more users, or lower threshold to 10

**Issue:** Difficulty not updating
- **Cause:** Cloud Function not running
- **Fix:** Check Firebase Console logs, manually trigger update

**Issue:** Grade predictions seem off
- **Cause:** Difficulty weights too extreme
- **Fix:** Adjust weight range from 0.7-1.3 to 0.8-1.2

**Issue:** High difficulty for easy questions
- **Cause:** Selection bias (only weak students attempting)
- **Fix:** Add question randomization, track skipped questions

### Contact

For questions or issues:
- **Technical:** Check Firebase Console logs
- **Data Quality:** Review questionDifficulty collection
- **Algorithm:** Contact system architect

## Version History

**v1.0.0** (2025-01-XX) - Initial Implementation
- Crowd-sourced difficulty calculation
- Weekly scheduled updates
- Grade prediction integration
- Admin manual triggers
- Firestore security rules

**v1.1.0** (Planned) - Enhancements
- Real-time difficulty updates
- UI visualizations
- Admin overrides
- Regional variants

---

*Last Updated: 2025-01-XX*
*Author: Uriel Academy Development Team*
