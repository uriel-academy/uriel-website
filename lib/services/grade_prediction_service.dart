import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/performance_data.dart';
import 'question_difficulty_service.dart';

class GradePredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QuestionDifficultyService _difficultyService = QuestionDifficultyService();

  // Model coefficients (can be tuned based on data analysis)
  static const double _alphaWeightedAvg = 0.50; // Weighted average accuracy
  static const double _betaImprovementTrend = 0.20; // Improvement trend
  static const double _gammaConsistency = 0.15; // Study consistency
  static const double _deltaAIPenalty = -0.10; // AI help dependence penalty
  static const double _epsilonRecentPerformance = 0.25; // Recent performance boost

  /// Calculate grade prediction for a student in a specific subject
  Future<GradePrediction> predictGrade({
    required String userId,
    required String subject,
  }) async {
    try {
      // 1. Fetch all question attempts for this user and subject
      final attemptsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('questionAttempts')
          .where('subject', isEqualTo: subject)
          .orderBy('attemptedAt', descending: true)
          .limit(500) // Limit to last 500 attempts
          .get();

      if (attemptsSnapshot.docs.isEmpty) {
        return _getDefaultPrediction(subject);
      }

      final attempts = attemptsSnapshot.docs
          .map((doc) => QuestionAttempt.fromMap(doc.data()))
          .toList();

      // 2. Calculate topic mastery
      final topicMasteryMap = _calculateTopicMastery(attempts);

      // 3. Calculate weighted average accuracy
      final weightedAvg = _calculateWeightedAverage(attempts);

      // 4. Calculate improvement trend
      final improvementTrend = _calculateImprovementTrend(attempts);

      // 5. Calculate study consistency
      final studyConsistency = _calculateStudyConsistency(attempts);

      // 6. Calculate AI help dependence
      final aiDependence = _calculateAIDependence(attempts);

      // 7. Calculate recent performance boost
      final recentPerformance = _calculateRecentPerformance(attempts);

      // 8. Combine all factors to get predicted score
      final predictedScore = _combinePredictionFactors(
        weightedAvg: weightedAvg,
        improvementTrend: improvementTrend,
        studyConsistency: studyConsistency,
        aiDependence: aiDependence,
        recentPerformance: recentPerformance,
      );

      // 9. Convert to BECE grade (1-9 scale)
      final predictedGrade = _scoreToGrade(predictedScore);

      // 10. Calculate confidence level
      final confidence = _calculateConfidence(attempts);

      // 11. Identify weak and strong topics
      final weakTopics = _identifyWeakTopics(topicMasteryMap);
      final strongTopics = _identifyStrongTopics(topicMasteryMap);

      // 12. Generate recommendation
      final recommendation = _generateRecommendation(
        grade: predictedGrade,
        score: predictedScore,
        weakTopics: weakTopics,
        improvementTrend: improvementTrend,
        studyConsistency: studyConsistency,
      );

      // 13. Create and save prediction
      final prediction = GradePrediction(
        subject: subject,
        predictedGrade: predictedGrade,
        predictedScore: predictedScore,
        confidence: confidence,
        confidenceLevel: _getConfidenceLevel(confidence),
        improvementTrend: improvementTrend,
        studyConsistency: studyConsistency,
        weakTopics: weakTopics,
        strongTopics: strongTopics,
        recommendation: recommendation,
        calculatedAt: DateTime.now(),
      );

      // Save to Firestore
      await _savePrediction(userId, prediction);

      return prediction;
    } catch (e) {
      print('Error predicting grade: $e');
      return _getDefaultPrediction(subject);
    }
  }

  /// Calculate weighted average accuracy with crowd-sourced difficulty and recency factors
  /// Uses dynamic difficulty based on how other students performed on each question
  double _calculateWeightedAverage(List<QuestionAttempt> attempts) {
    if (attempts.isEmpty) return 0.0;

    double totalWeightedScore = 0.0;
    double totalWeight = 0.0;

    for (final attempt in attempts) {
      // Use crowd-sourced difficulty from actual performance data
      // This replaces the static difficultyWeight with dynamic calculation
      final crowdSourcedDifficulty = attempt.difficultyWeight;
      
      final weight = crowdSourcedDifficulty * attempt.recencyFactor;
      totalWeightedScore += (attempt.isCorrect ? 1.0 : 0.0) * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? (totalWeightedScore / totalWeight) : 0.0;
  }

  /// Calculate improvement trend (comparing recent vs older performance)
  double _calculateImprovementTrend(List<QuestionAttempt> attempts) {
    if (attempts.length < 10) return 0.0;

    // Split into recent (last 30 days) and older (31-90 days)
    final now = DateTime.now();
    final recent = attempts
        .where((a) => now.difference(a.attemptedAt).inDays <= 30)
        .toList();
    final older = attempts
        .where((a) {
          final days = now.difference(a.attemptedAt).inDays;
          return days > 30 && days <= 90;
        })
        .toList();

    if (recent.isEmpty || older.isEmpty) return 0.0;

    final recentAccuracy = recent.where((a) => a.isCorrect).length / recent.length;
    final olderAccuracy = older.where((a) => a.isCorrect).length / older.length;

    // Return normalized trend (-1 to 1)
    return (recentAccuracy - olderAccuracy).clamp(-1.0, 1.0);
  }

  /// Calculate study consistency based on frequency and regularity
  double _calculateStudyConsistency(List<QuestionAttempt> attempts) {
    if (attempts.length < 5) return 0.0;

    // Calculate days between attempts
    final sortedAttempts = List<QuestionAttempt>.from(attempts)
      ..sort((a, b) => a.attemptedAt.compareTo(b.attemptedAt));

    final intervals = <int>[];
    for (int i = 1; i < sortedAttempts.length; i++) {
      final daysBetween = sortedAttempts[i].attemptedAt
          .difference(sortedAttempts[i - 1].attemptedAt)
          .inDays;
      intervals.add(daysBetween);
    }

    if (intervals.isEmpty) return 0.0;

    // Calculate standard deviation of intervals
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    final variance = intervals
        .map((i) => pow(i - mean, 2))
        .reduce((a, b) => a + b) / intervals.length;
    final stdDev = sqrt(variance);

    // Lower standard deviation = higher consistency
    // Normalize to 0-1 range (assume max reasonable stdDev is 14 days)
    final consistency = 1.0 - (stdDev / 14.0).clamp(0.0, 1.0);

    return consistency;
  }

  /// Calculate AI help dependence (higher = relies more on AI)
  double _calculateAIDependence(List<QuestionAttempt> attempts) {
    if (attempts.isEmpty) return 0.0;

    final aiAssistedCount = attempts.where((a) => a.usedAIAssistance).length;
    return aiAssistedCount / attempts.length;
  }

  /// Calculate recent performance (last 2 weeks)
  double _calculateRecentPerformance(List<QuestionAttempt> attempts) {
    final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
    final recentAttempts = attempts
        .where((a) => a.attemptedAt.isAfter(twoWeeksAgo))
        .toList();

    if (recentAttempts.isEmpty) return 0.0;

    final correctCount = recentAttempts.where((a) => a.isCorrect).length;
    return correctCount / recentAttempts.length;
  }

  /// Combine all prediction factors into final score
  double _combinePredictionFactors({
    required double weightedAvg,
    required double improvementTrend,
    required double studyConsistency,
    required double aiDependence,
    required double recentPerformance,
  }) {
    final score = (_alphaWeightedAvg * weightedAvg) +
        (_betaImprovementTrend * improvementTrend) +
        (_gammaConsistency * studyConsistency) +
        (_deltaAIPenalty * aiDependence) +
        (_epsilonRecentPerformance * recentPerformance);

    // Convert to 0-100 scale and clamp
    return (score * 100).clamp(0.0, 100.0);
  }

  /// Convert percentage score to BECE grade (1-9 scale)
  int _scoreToGrade(double score) {
    if (score >= 85) return 1; // Grade 1: 85-100
    if (score >= 75) return 2; // Grade 2: 75-84
    if (score >= 65) return 3; // Grade 3: 65-74
    if (score >= 55) return 4; // Grade 4: 55-64
    if (score >= 50) return 5; // Grade 5: 50-54
    if (score >= 45) return 6; // Grade 6: 45-49
    if (score >= 40) return 7; // Grade 7: 40-44
    if (score >= 35) return 8; // Grade 8: 35-39
    return 9; // Grade 9: Below 35
  }

  /// Calculate confidence based on variance of recent scores
  double _calculateConfidence(List<QuestionAttempt> attempts) {
    if (attempts.length < 10) return 0.3; // Low confidence with few attempts

    // Get last 20 attempts (or fewer if not available)
    final recentAttempts = attempts.take(min(20, attempts.length)).toList();

    // Calculate scores for each attempt (1 for correct, 0 for incorrect)
    final scores = recentAttempts.map((a) => a.isCorrect ? 1.0 : 0.0).toList();

    // Calculate variance
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores
        .map((s) => pow(s - mean, 2))
        .reduce((a, b) => a + b) / scores.length;

    // Convert variance to confidence (lower variance = higher confidence)
    // Variance range is 0 to 0.25 (for binary outcomes)
    final confidence = 1.0 - (variance / 0.25);

    return confidence.clamp(0.0, 1.0);
  }

  /// Get confidence level label
  String _getConfidenceLevel(double confidence) {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    return 'Low';
  }

  /// Calculate mastery for each topic
  Map<String, TopicMastery> _calculateTopicMastery(List<QuestionAttempt> attempts) {
    final topicMap = <String, List<QuestionAttempt>>{};

    // Group attempts by topic
    for (final attempt in attempts) {
      topicMap.putIfAbsent(attempt.topic, () => []).add(attempt);
    }

    // Calculate mastery for each topic
    final masteryMap = <String, TopicMastery>{};
    for (final entry in topicMap.entries) {
      final topic = entry.key;
      final topicAttempts = entry.value;

      final correctCount = topicAttempts.where((a) => a.isCorrect).length;
      final totalCount = topicAttempts.length;

      // Calculate weighted mastery score
      double totalWeightedScore = 0.0;
      double totalWeight = 0.0;
      int totalTime = 0;

      for (final attempt in topicAttempts) {
        final weight = attempt.difficultyWeight * attempt.recencyFactor;
        totalWeightedScore += (attempt.isCorrect ? 1.0 : 0.0) * weight;
        totalWeight += weight;
        totalTime += attempt.timeSpentSeconds;
      }

      final masteryScore = totalWeight > 0 ? (totalWeightedScore / totalWeight) : 0.0;
      final avgTime = totalCount > 0 ? totalTime / totalCount : 0.0;

      masteryMap[topic] = TopicMastery(
        topic: topic,
        masteryScore: masteryScore,
        totalAttempts: totalCount,
        correctAttempts: correctCount,
        averageTimeSpent: avgTime,
        lastAttempted: topicAttempts.first.attemptedAt,
      );
    }

    return masteryMap;
  }

  /// Identify weak topics (mastery < 0.6)
  List<String> _identifyWeakTopics(Map<String, TopicMastery> masteryMap) {
    return masteryMap.entries
        .where((e) => e.value.masteryScore < 0.6)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) {
        final aMastery = masteryMap[a]!.masteryScore;
        final bMastery = masteryMap[b]!.masteryScore;
        return aMastery.compareTo(bMastery); // Weakest first
      });
  }

  /// Identify strong topics (mastery >= 0.8)
  List<String> _identifyStrongTopics(Map<String, TopicMastery> masteryMap) {
    return masteryMap.entries
        .where((e) => e.value.masteryScore >= 0.8)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) {
        final aMastery = masteryMap[a]!.masteryScore;
        final bMastery = masteryMap[b]!.masteryScore;
        return bMastery.compareTo(aMastery); // Strongest first
      });
  }

  /// Generate personalized recommendation
  String _generateRecommendation({
    required int grade,
    required double score,
    required List<String> weakTopics,
    required double improvementTrend,
    required double studyConsistency,
  }) {
    final recommendations = <String>[];

    // Grade-based recommendations
    if (grade <= 3) {
      recommendations.add('Excellent work! You\'re on track for a distinction.');
    } else if (grade <= 6) {
      recommendations.add('Good progress. With focused effort, you can reach distinction level.');
    } else {
      recommendations.add('You need consistent practice to improve your grade.');
    }

    // Weak topics recommendations
    if (weakTopics.isNotEmpty) {
      if (weakTopics.length == 1) {
        recommendations.add('Focus on improving "${weakTopics.first}" to boost your grade.');
      } else {
        recommendations.add(
            'Prioritize these weak areas: ${weakTopics.take(3).join(", ")}.');
      }
    }

    // Consistency recommendations
    if (studyConsistency < 0.5) {
      recommendations.add('Study more regularly to build better retention.');
    }

    // Trend recommendations
    if (improvementTrend < -0.2) {
      recommendations.add('Your performance is declining. Review past topics and practice more.');
    } else if (improvementTrend > 0.2) {
      recommendations.add('Great improvement! Keep up the momentum.');
    }

    // Calculate improvement needed for next grade
    if (grade < 9) {
      final nextGradeThreshold = _getGradeThreshold(grade - 1);
      final improvementNeeded = nextGradeThreshold - score;
      if (improvementNeeded > 0) {
        recommendations.add(
            'Improve by ${improvementNeeded.toStringAsFixed(1)}% to reach Grade ${grade - 1}.');
      }
    }

    return recommendations.join(' ');
  }

  /// Get minimum score threshold for a grade
  double _getGradeThreshold(int grade) {
    switch (grade) {
      case 1:
        return 85.0;
      case 2:
        return 75.0;
      case 3:
        return 65.0;
      case 4:
        return 55.0;
      case 5:
        return 50.0;
      case 6:
        return 45.0;
      case 7:
        return 40.0;
      case 8:
        return 35.0;
      default:
        return 0.0;
    }
  }

  /// Get default prediction for users with no data
  GradePrediction _getDefaultPrediction(String subject) {
    return GradePrediction(
      subject: subject,
      predictedGrade: 9,
      predictedScore: 0.0,
      confidence: 0.0,
      confidenceLevel: 'Insufficient Data',
      improvementTrend: 0.0,
      studyConsistency: 0.0,
      weakTopics: [],
      strongTopics: [],
      recommendation: 'Start practicing questions to get a grade prediction.',
      calculatedAt: DateTime.now(),
    );
  }

  /// Save prediction to Firestore
  Future<void> _savePrediction(String userId, GradePrediction prediction) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('gradePredictions')
        .doc(prediction.subject)
        .set(prediction.toMap());
  }

  /// Get cached prediction from Firestore
  Future<GradePrediction?> getCachedPrediction({
    required String userId,
    required String subject,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('gradePredictions')
          .doc(subject)
          .get();

      if (!doc.exists) return null;

      final prediction = GradePrediction.fromMap(doc.data()!);

      // Check if prediction is stale (older than 24 hours)
      final hoursSinceCalculation =
          DateTime.now().difference(prediction.calculatedAt).inHours;

      if (hoursSinceCalculation > 24) {
        return null; // Force recalculation
      }

      return prediction;
    } catch (e) {
      print('Error fetching cached prediction: $e');
      return null;
    }
  }

  /// Batch predict grades for all subjects
  Future<Map<String, GradePrediction>> predictAllGrades({
    required String userId,
    List<String> subjects = const [
      'religiousMoralEducation',
      'ict',
      'mathematics',
      'english',
      'science',
      'social_studies',
    ],
  }) async {
    final predictions = <String, GradePrediction>{};

    for (final subject in subjects) {
      try {
        // Try to get cached prediction first
        final cached = await getCachedPrediction(
          userId: userId,
          subject: subject,
        );

        if (cached != null) {
          predictions[subject] = cached;
        } else {
          // Calculate new prediction
          final prediction = await predictGrade(
            userId: userId,
            subject: subject,
          );
          predictions[subject] = prediction;
        }
      } catch (e) {
        print('Error predicting grade for $subject: $e');
        predictions[subject] = _getDefaultPrediction(subject);
      }
    }

    return predictions;
  }
}
