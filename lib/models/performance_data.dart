import 'package:flutter/material.dart';

// Performance data models for grade prediction

class QuestionAttempt {
  final String questionId;
  final String year;
  final String difficulty; // 'easy', 'medium', 'hard'
  final int timeSpentSeconds;
  final int attemptsBeforeCorrect;
  final bool usedHint;
  final bool usedAIAssistance;
  final DateTime attemptedAt;
  final bool isCorrect;
  final String topic;
  final String subject;

  QuestionAttempt({
    required this.questionId,
    required this.year,
    required this.difficulty,
    required this.timeSpentSeconds,
    required this.attemptsBeforeCorrect,
    required this.usedHint,
    required this.usedAIAssistance,
    required this.attemptedAt,
    required this.isCorrect,
    required this.topic,
    required this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'year': year,
      'difficulty': difficulty,
      'timeSpentSeconds': timeSpentSeconds,
      'attemptsBeforeCorrect': attemptsBeforeCorrect,
      'usedHint': usedHint,
      'usedAIAssistance': usedAIAssistance,
      'attemptedAt': attemptedAt.toIso8601String(),
      'isCorrect': isCorrect,
      'topic': topic,
      'subject': subject,
    };
  }

  factory QuestionAttempt.fromMap(Map<String, dynamic> map) {
    return QuestionAttempt(
      questionId: map['questionId'] ?? '',
      year: map['year'] ?? '',
      difficulty: map['difficulty'] ?? 'medium',
      timeSpentSeconds: map['timeSpentSeconds'] ?? 0,
      attemptsBeforeCorrect: map['attemptsBeforeCorrect'] ?? 1,
      usedHint: map['usedHint'] ?? false,
      usedAIAssistance: map['usedAIAssistance'] ?? false,
      attemptedAt: DateTime.parse(map['attemptedAt']),
      isCorrect: map['isCorrect'] ?? false,
      topic: map['topic'] ?? '',
      subject: map['subject'] ?? '',
    );
  }

  // Calculate difficulty weight
  double get difficultyWeight {
    // Crowd-sourced difficulty calculation:
    // Will be calculated as: 1 - (successRate)
    // 90% success = 0.1 difficulty (easy) → weight 0.8
    // 50% success = 0.5 difficulty (medium) → weight 1.0
    // 20% success = 0.8 difficulty (hard) → weight 1.2
    
    // For backward compatibility with existing data:
    switch (difficulty.toLowerCase()) {
      case 'hard':
      case 'difficult':
        return 1.2;
      case 'easy':
        return 0.8;
      case 'medium':
      default:
        // Default to neutral weight for BECE questions
        // This acknowledges that BECE doesn't officially classify difficulty
        return 1.0;
    }
  }

  // Calculate recency factor
  double get recencyFactor {
    final daysSinceAttempt = DateTime.now().difference(attemptedAt).inDays;
    if (daysSinceAttempt <= 30) return 1.0;
    if (daysSinceAttempt <= 90) return 0.8;
    return 0.6;
  }

  // Calculate weighted score
  double get weightedScore {
    if (!isCorrect) return 0.0;
    return difficultyWeight * recencyFactor;
  }
}

class TopicMastery {
  final String topic;
  final double masteryScore; // 0.0 to 1.0
  final int totalAttempts;
  final int correctAttempts;
  final double averageTimeSpent;
  final DateTime lastAttempted;

  TopicMastery({
    required this.topic,
    required this.masteryScore,
    required this.totalAttempts,
    required this.correctAttempts,
    required this.averageTimeSpent,
    required this.lastAttempted,
  });

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'masteryScore': masteryScore,
      'totalAttempts': totalAttempts,
      'correctAttempts': correctAttempts,
      'averageTimeSpent': averageTimeSpent,
      'lastAttempted': lastAttempted.toIso8601String(),
    };
  }

  factory TopicMastery.fromMap(Map<String, dynamic> map) {
    return TopicMastery(
      topic: map['topic'] ?? '',
      masteryScore: (map['masteryScore'] ?? 0.0).toDouble(),
      totalAttempts: map['totalAttempts'] ?? 0,
      correctAttempts: map['correctAttempts'] ?? 0,
      averageTimeSpent: (map['averageTimeSpent'] ?? 0.0).toDouble(),
      lastAttempted: DateTime.parse(map['lastAttempted']),
    );
  }
}

class GradePrediction {
  final String subject;
  final int predictedGrade; // 1-9 scale (Ghanaian BECE grading)
  final double predictedScore; // 0-100 percentage
  final double confidence; // 0.0 to 1.0
  final String confidenceLevel; // 'High', 'Medium', 'Low'
  final double improvementTrend; // -1.0 to 1.0
  final double studyConsistency; // 0.0 to 1.0
  final List<String> weakTopics;
  final List<String> strongTopics;
  final String recommendation;
  final DateTime calculatedAt;
  
  // 95% Confidence Interval
  final double marginOfError; // ±margin at 95% confidence
  final double lowerBound; // Lower grade bound
  final double upperBound; // Upper grade bound
  
  // Topic Diversity Requirements
  final int totalAttempts; // Total quiz attempts
  final int uniqueTopicsCovered; // Unique topics covered
  final int requiredTopics; // Required topics for prediction (40% of total)
  final int uniqueCollectionsCovered; // Unique quiz collections/sets covered
  final int requiredCollections; // Required collections for diversity
  final bool meetsRequirements; // Whether requirements are met
  final bool usedTheory; // Whether student engaged with theory content
  final int mcqAttempts; // MCQ quiz attempts
  final int theoryAttempts; // Theory question attempts

  GradePrediction({
    required this.subject,
    required this.predictedGrade,
    required this.predictedScore,
    required this.confidence,
    required this.confidenceLevel,
    required this.improvementTrend,
    required this.studyConsistency,
    required this.weakTopics,
    required this.strongTopics,
    required this.recommendation,
    required this.calculatedAt,
    required this.marginOfError,
    required this.lowerBound,
    required this.upperBound,
    required this.totalAttempts,
    required this.uniqueTopicsCovered,
    required this.requiredTopics,
    required this.uniqueCollectionsCovered,
    required this.requiredCollections,
    required this.meetsRequirements,
    required this.usedTheory,
    required this.mcqAttempts,
    required this.theoryAttempts,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'predictedGrade': predictedGrade,
      'predictedScore': predictedScore,
      'confidence': confidence,
      'confidenceLevel': confidenceLevel,
      'improvementTrend': improvementTrend,
      'studyConsistency': studyConsistency,
      'weakTopics': weakTopics,
      'strongTopics': strongTopics,
      'recommendation': recommendation,
      'calculatedAt': calculatedAt.toIso8601String(),
      'marginOfError': marginOfError,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
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

  factory GradePrediction.fromMap(Map<String, dynamic> map) {
    return GradePrediction(
      subject: map['subject'] ?? '',
      predictedGrade: map['predictedGrade'] ?? 9,
      predictedScore: (map['predictedScore'] ?? 0.0).toDouble(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      confidenceLevel: map['confidenceLevel'] ?? 'Low',
      improvementTrend: (map['improvementTrend'] ?? 0.0).toDouble(),
      studyConsistency: (map['studyConsistency'] ?? 0.0).toDouble(),
      weakTopics: List<String>.from(map['weakTopics'] ?? []),
      strongTopics: List<String>.from(map['strongTopics'] ?? []),
      recommendation: map['recommendation'] ?? '',
      calculatedAt: DateTime.parse(map['calculatedAt']),
      marginOfError: (map['marginOfError'] ?? 0.0).toDouble(),
      lowerBound: (map['lowerBound'] ?? 0.0).toDouble(),
      upperBound: (map['upperBound'] ?? 0.0).toDouble(),
      totalAttempts: map['totalAttempts'] ?? 0,
      uniqueTopicsCovered: map['uniqueTopicsCovered'] ?? 0,
      requiredTopics: map['requiredTopics'] ?? 0,
      uniqueCollectionsCovered: map['uniqueCollectionsCovered'] ?? 0,
      requiredCollections: map['requiredCollections'] ?? 0,
      meetsRequirements: map['meetsRequirements'] ?? false,
      usedTheory: map['usedTheory'] ?? false,
      mcqAttempts: map['mcqAttempts'] ?? 0,
      theoryAttempts: map['theoryAttempts'] ?? 0,
    );
  }

  // Get grade label
  String get gradeLabel {
    switch (predictedGrade) {
      case 1:
        return 'Grade 1 (Highest Distinction)';
      case 2:
        return 'Grade 2 (Higher Distinction)';
      case 3:
        return 'Grade 3 (Distinction)';
      case 4:
        return 'Grade 4 (High Credit)';
      case 5:
        return 'Grade 5 (Credit)';
      case 6:
        return 'Grade 6 (High Pass)';
      case 7:
        return 'Grade 7 (Pass)';
      case 8:
        return 'Grade 8 (Low Pass)';
      case 9:
        return 'Grade 9 (Fail)';
      default:
        return 'Unknown';
    }
  }

  // Get color for grade
  Color get gradeColor {
    if (predictedGrade <= 2) return Colors.green;
    if (predictedGrade <= 4) return Colors.blue;
    if (predictedGrade <= 6) return Colors.orange;
    if (predictedGrade <= 8) return Colors.deepOrange;
    return Colors.red;
  }

  // Get confidence color
  Color get confidenceColor {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
