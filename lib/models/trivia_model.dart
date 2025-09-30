import 'package:flutter/material.dart';

class TriviaChallenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final String gameMode;
  final int questionCount;
  final int timeLimit; // in minutes
  final int points;
  final bool isNew;
  final bool isActive;
  final DateTime createdDate;
  final DateTime? expiryDate;
  final int participants;
  final List<String> tags;
  final String imageUrl;
  final Map<String, dynamic> rules;
  final int minLevel;
  final bool isMultiplayer;
  final int maxPlayers;

  TriviaChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.gameMode,
    required this.questionCount,
    required this.timeLimit,
    required this.points,
    this.isNew = false,
    this.isActive = true,
    required this.createdDate,
    this.expiryDate,
    this.participants = 0,
    required this.tags,
    this.imageUrl = '',
    required this.rules,
    this.minLevel = 1,
    this.isMultiplayer = false,
    this.maxPlayers = 1,
  });

  factory TriviaChallenge.fromJson(Map<String, dynamic> json) {
    return TriviaChallenge(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? '',
      gameMode: json['gameMode'] ?? '',
      questionCount: json['questionCount'] ?? 0,
      timeLimit: json['timeLimit'] ?? 0,
      points: json['points'] ?? 0,
      isNew: json['isNew'] ?? false,
      isActive: json['isActive'] ?? true,
      createdDate: DateTime.parse(json['createdDate'] ?? DateTime.now().toIso8601String()),
      expiryDate: json['expiryDate'] != null 
          ? DateTime.parse(json['expiryDate']) 
          : null,
      participants: json['participants'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      rules: Map<String, dynamic>.from(json['rules'] ?? {}),
      minLevel: json['minLevel'] ?? 1,
      isMultiplayer: json['isMultiplayer'] ?? false,
      maxPlayers: json['maxPlayers'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'gameMode': gameMode,
      'questionCount': questionCount,
      'timeLimit': timeLimit,
      'points': points,
      'isNew': isNew,
      'isActive': isActive,
      'createdDate': createdDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'participants': participants,
      'tags': tags,
      'imageUrl': imageUrl,
      'rules': rules,
      'minLevel': minLevel,
      'isMultiplayer': isMultiplayer,
      'maxPlayers': maxPlayers,
    };
  }

  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);
  
  bool get isAvailable => isActive && !isExpired;
  
  String get difficultyLabel {
    switch (difficulty.toLowerCase()) {
      case 'easy': return '⭐';
      case 'medium': return '⭐⭐';
      case 'hard': return '⭐⭐⭐';
      case 'expert': return '⭐⭐⭐⭐';
      default: return '⭐';
    }
  }

  Color get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'easy': return const Color(0xFF4CAF50);
      case 'medium': return const Color(0xFFFF9800);
      case 'hard': return const Color(0xFFFF5722);
      case 'expert': return const Color(0xFF9C27B0);
      default: return const Color(0xFF607D8B);
    }
  }
}

class TriviaResult {
  final String id;
  final String challengeId;
  final String userId;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final Duration timeTaken;
  final DateTime completedDate;
  final Map<String, dynamic> answerDetails;
  final int pointsEarned;
  final String rank;

  TriviaResult({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeTaken,
    required this.completedDate,
    required this.answerDetails,
    required this.pointsEarned,
    required this.rank,
  });

  factory TriviaResult.fromJson(Map<String, dynamic> json) {
    return TriviaResult(
      id: json['id'] ?? '',
      challengeId: json['challengeId'] ?? '',
      userId: json['userId'] ?? '',
      score: json['score'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      timeTaken: Duration(seconds: json['timeTaken'] ?? 0),
      completedDate: DateTime.parse(json['completedDate'] ?? DateTime.now().toIso8601String()),
      answerDetails: Map<String, dynamic>.from(json['answerDetails'] ?? {}),
      pointsEarned: json['pointsEarned'] ?? 0,
      rank: json['rank'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challengeId': challengeId,
      'userId': userId,
      'score': score,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'timeTaken': timeTaken.inSeconds,
      'completedDate': completedDate.toIso8601String(),
      'answerDetails': answerDetails,
      'pointsEarned': pointsEarned,
      'rank': rank,
    };
  }

  double get percentage => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0.0;
  
  String get gradeLabel {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }
}