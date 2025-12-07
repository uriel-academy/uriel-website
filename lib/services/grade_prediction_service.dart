import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/performance_data.dart';

class GradePredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // 10. Calculate 95% confidence interval
      final ciData = _calculate95ConfidenceInterval(attempts, predictedScore);
      final confidence = ciData['confidence'] as double;

      // 11. Calculate topic diversity and collection coverage
      final diversityData = await _calculateTopicDiversity(userId, subject, attempts);

      // 12. Identify weak and strong topics
      final weakTopics = _identifyWeakTopics(topicMasteryMap);
      final strongTopics = _identifyStrongTopics(topicMasteryMap);

      // 13. Generate recommendation
      final recommendation = _generateRecommendation(
        grade: predictedGrade,
        score: predictedScore,
        weakTopics: weakTopics,
        improvementTrend: improvementTrend,
        studyConsistency: studyConsistency,
        meetsRequirements: diversityData['meetsRequirements'] as bool,
        topicCoverage: diversityData['uniqueTopicsCovered'] as int,
        requiredTopics: diversityData['requiredTopics'] as int,
      );

      // 14. Create and save prediction
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
        marginOfError: ciData['marginOfError'] as double,
        lowerBound: ciData['lowerBound'] as double,
        upperBound: ciData['upperBound'] as double,
        totalAttempts: diversityData['totalAttempts'] as int,
        uniqueTopicsCovered: diversityData['uniqueTopicsCovered'] as int,
        requiredTopics: diversityData['requiredTopics'] as int,
        uniqueCollectionsCovered: diversityData['uniqueCollectionsCovered'] as int,
        requiredCollections: diversityData['requiredCollections'] as int,
        meetsRequirements: diversityData['meetsRequirements'] as bool,
        usedTheory: diversityData['usedTheory'] as bool,
        mcqAttempts: diversityData['mcqAttempts'] as int,
        theoryAttempts: diversityData['theoryAttempts'] as int,
      );

      // Save to Firestore
      await _savePrediction(userId, prediction);

      return prediction;
    } catch (e) {
      debugPrint('Error predicting grade: $e');
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
  /// Adjusted Ghana BECE grading: Grade 1 (80-100%), Grade 2 (70-79%), etc.
  int _scoreToGrade(double score) {
    if (score >= 80) return 1; // Grade 1: 80-100 (Highest Distinction)
    if (score >= 70) return 2; // Grade 2: 70-79 (Higher Distinction)
    if (score >= 60) return 3; // Grade 3: 60-69 (Distinction)
    if (score >= 50) return 4; // Grade 4: 50-59 (High Credit)
    if (score >= 45) return 5; // Grade 5: 45-49 (Credit)
    if (score >= 40) return 6; // Grade 6: 40-44 (High Pass)
    if (score >= 35) return 7; // Grade 7: 35-39 (Pass)
    if (score >= 30) return 8; // Grade 8: 30-34 (Low Pass)
    return 9; // Grade 9: Below 30 (Fail)
  }

  /// Calculate 95% confidence interval using binomial proportion standard error
  Map<String, dynamic> _calculate95ConfidenceInterval(
    List<QuestionAttempt> attempts,
    double predictedScore,
  ) {
    if (attempts.length < 10) {
      return {
        'confidence': 0.3,
        'marginOfError': 0.0,
        'lowerBound': predictedScore,
        'upperBound': predictedScore,
      };
    }

    // Get last 20 attempts for CI calculation
    final recentAttempts = attempts.take(min(20, attempts.length)).toList();
    final n = recentAttempts.length;
    final correctCount = recentAttempts.where((a) => a.isCorrect).length;
    final accuracy = correctCount / n;

    // Calculate standard error using binomial proportion formula
    // SE = sqrt(p * (1 - p) / n)
    final standardError = sqrt(accuracy * (1 - accuracy) / n);

    // Calculate margin of error at 95% confidence (z = 1.96)
    final marginOfError = 1.96 * standardError;

    // Calculate bounds in grade scale (0-100)
    final lowerBound = ((accuracy - marginOfError) * 100).clamp(0.0, 100.0);
    final upperBound = ((accuracy + marginOfError) * 100).clamp(0.0, 100.0);

    // Convert margin to confidence (smaller margin = higher confidence)
    // Margin typically ranges from 0 to ~0.5 for small samples
    final confidence = (1.0 - (marginOfError * 2)).clamp(0.0, 1.0);

    return {
      'confidence': confidence,
      'marginOfError': marginOfError,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
    };
  }

  /// Calculate topic diversity and collection coverage
  Future<Map<String, dynamic>> _calculateTopicDiversity(
    String userId,
    String subject,
    List<QuestionAttempt> attempts,
  ) async {
    // Get total quiz attempts count
    final totalAttempts = attempts.length;

    // Count unique topics covered
    final uniqueTopics = attempts.map((a) => a.topic).toSet();
    final uniqueTopicsCovered = uniqueTopics.length;

    // Count unique collections from quiz attempts
    final quizzesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quizzes')
        .where('subject', isEqualTo: subject)
        .where('isCompleted', isEqualTo: true)
        .get();

    final quizzes = quizzesSnapshot.docs;
    final uniqueCollections = quizzes.map((doc) {
      final data = doc.data();
      return data['collectionName'] ?? data['year'] ?? 'Unknown';
    }).toSet();
    final uniqueCollectionsCovered = uniqueCollections.length;

    // Count MCQ vs Theory attempts
    int mcqAttempts = 0;
    int theoryAttempts = 0;
    
    for (final quiz in quizzes) {
      final data = quiz.data();
      final quizType = data['quizType'] ?? '';
      if (quizType.toLowerCase().contains('mcq') || 
          quizType.toLowerCase().contains('multiple')) {
        mcqAttempts++;
      } else if (quizType.toLowerCase().contains('theory') || 
                 quizType.toLowerCase().contains('essay')) {
        theoryAttempts++;
      }
    }

    final usedTheory = theoryAttempts > 0;

    // Fetch total available collections for this subject
    final collectionsSnapshot = await _firestore
        .collection('questionCollections')
        .where('subject', isEqualTo: subject)
        .get();

    final totalCollections = collectionsSnapshot.docs.length;
    final requiredCollections = (totalCollections * 0.4).ceil(); // 40% of total

    // Calculate required topics (assume 3 topics per collection on average)
    final estimatedTotalTopics = max(totalCollections * 3, uniqueTopicsCovered);
    final requiredTopics = (estimatedTotalTopics * 0.4).ceil(); // 40% coverage

    // Check if requirements are met
    final meetsRequirements = totalAttempts >= 20 &&
        uniqueCollectionsCovered >= requiredCollections;

    return {
      'totalAttempts': totalAttempts,
      'uniqueTopicsCovered': uniqueTopicsCovered,
      'requiredTopics': requiredTopics,
      'uniqueCollectionsCovered': uniqueCollectionsCovered,
      'requiredCollections': requiredCollections,
      'meetsRequirements': meetsRequirements,
      'usedTheory': usedTheory,
      'mcqAttempts': mcqAttempts,
      'theoryAttempts': theoryAttempts,
    };
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

  /// Get grade predictions for multiple students (for teachers/admins)
  /// Returns Map<subject, Map<grade, List<studentId>>>
  Future<Map<String, Map<int, List<String>>>> getGradeDistribution({
    required List<String> studentIds,
    List<String>? subjects,
  }) async {
    // All BECE subjects if not specified
    final subjectsToCheck = subjects ?? [
      'Mathematics',
      'English Language',
      'Integrated Science',
      'Social Studies',
      'RME',
      'ICT',
      'Ga',
      'Asante Twi',
      'French',
      'Creative Arts',
      'Career Technology',
    ];

    final distribution = <String, Map<int, List<String>>>{};

    // Initialize distribution structure
    for (final subject in subjectsToCheck) {
      distribution[subject] = {};
      for (int grade = 1; grade <= 9; grade++) {
        distribution[subject]![grade] = [];
      }
    }

    // Fetch predictions for each student and subject
    for (final studentId in studentIds) {
      for (final subject in subjectsToCheck) {
        try {
          final prediction = await predictGrade(
            userId: studentId,
            subject: subject,
          );

          // Only count if requirements are met
          if (prediction.meetsRequirements) {
            distribution[subject]![prediction.predictedGrade]!.add(studentId);
          }
        } catch (e) {
          debugPrint('Error predicting for $studentId in $subject: $e');
        }
      }
    }

    return distribution;
  }

  /// Get aggregated grade statistics for a subject
  /// Returns Map with statistics like average, distribution, etc.
  Future<Map<String, dynamic>> getSubjectStatistics({
    required List<String> studentIds,
    required String subject,
  }) async {
    final predictions = <GradePrediction>[];

    for (final studentId in studentIds) {
      try {
        final prediction = await predictGrade(
          userId: studentId,
          subject: subject,
        );

        if (prediction.meetsRequirements) {
          predictions.add(prediction);
        }
      } catch (e) {
        debugPrint('Error predicting for $studentId: $e');
      }
    }

    if (predictions.isEmpty) {
      return {
        'totalStudents': studentIds.length,
        'studentsWithPredictions': 0,
        'averageGrade': 0.0,
        'averageScore': 0.0,
        'gradeDistribution': <int, int>{},
        'topPerformers': <String>[],
        'needsSupport': <String>[],
      };
    }

    // Calculate statistics
    final totalPredicted = predictions.length;
    final avgGrade = predictions.map((p) => p.predictedGrade).reduce((a, b) => a + b) / totalPredicted;
    final avgScore = predictions.map((p) => p.predictedScore).reduce((a, b) => a + b) / totalPredicted;

    // Grade distribution
    final gradeDistribution = <int, int>{};
    for (int grade = 1; grade <= 9; grade++) {
      gradeDistribution[grade] = predictions.where((p) => p.predictedGrade == grade).length;
    }

    return {
      'totalStudents': studentIds.length,
      'studentsWithPredictions': totalPredicted,
      'averageGrade': avgGrade,
      'averageScore': avgScore,
      'gradeDistribution': gradeDistribution,
      'predictions': predictions,
    };
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
    required bool meetsRequirements,
    required int topicCoverage,
    required int requiredTopics,
  }) {
    final recommendations = <String>[];

    // Requirements check
    if (!meetsRequirements) {
      final topicsNeeded = requiredTopics - topicCoverage;
      if (topicsNeeded > 0) {
        recommendations.add(
          'Complete quizzes across $topicsNeeded more topics to unlock your grade prediction.'
        );
      }
      recommendations.add(
        'Try exploring different quiz collections to get a comprehensive assessment.'
      );
      return recommendations.join(' ');
    }

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

  /// Get minimum score threshold for a grade (Adjusted BECE thresholds)
  double _getGradeThreshold(int grade) {
    switch (grade) {
      case 1:
        return 80.0; // Grade 1: 80-100%
      case 2:
        return 70.0; // Grade 2: 70-79%
      case 3:
        return 60.0; // Grade 3: 60-69%
      case 4:
        return 50.0; // Grade 4: 50-59%
      case 5:
        return 45.0; // Grade 5: 45-49%
      case 6:
        return 40.0; // Grade 6: 40-44%
      case 7:
        return 35.0; // Grade 7: 35-39%
      case 8:
        return 30.0; // Grade 8: 30-34%
      default:
        return 0.0; // Grade 9: Below 30%
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
      marginOfError: 0.0,
      lowerBound: 0.0,
      upperBound: 0.0,
      totalAttempts: 0,
      uniqueTopicsCovered: 0,
      requiredTopics: 0,
      uniqueCollectionsCovered: 0,
      requiredCollections: 0,
      meetsRequirements: false,
      usedTheory: false,
      mcqAttempts: 0,
      theoryAttempts: 0,
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
