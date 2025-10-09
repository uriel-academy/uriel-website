import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'xp_service.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int xpReward;
  final String rarity; // Common, Rare, Epic, Legendary
  final String category;
  final Map<String, dynamic> requirements;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.rarity,
    required this.category,
    required this.requirements,
  });
}

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Define all achievements
  final List<Achievement> allAchievements = [
    // Accuracy Achievements
    Achievement(
      id: 'accuracy_master',
      name: 'Accuracy Master',
      description: 'Achieve 95%+ accuracy on 50 questions',
      icon: '🎯',
      xpReward: 100,
      rarity: 'Epic',
      category: 'Accuracy',
      requirements: {'accuracyThreshold': 95, 'questionsRequired': 50},
    ),
    Achievement(
      id: 'perfectionist',
      name: 'Perfectionist',
      description: 'Score 100% on 10 quizzes',
      icon: '💯',
      xpReward: 150,
      rarity: 'Epic',
      category: 'Accuracy',
      requirements: {'perfectScoresRequired': 10},
    ),

    // Streak Achievements
    Achievement(
      id: 'streak_champion',
      name: 'Streak Champion',
      description: 'Maintain a 30-day study streak',
      icon: '🔥',
      xpReward: 200,
      rarity: 'Legendary',
      category: 'Streak',
      requirements: {'streakDays': 30},
    ),
    Achievement(
      id: 'week_warrior',
      name: 'Week Warrior',
      description: 'Study for 7 consecutive days',
      icon: '⚡',
      xpReward: 50,
      rarity: 'Rare',
      category: 'Streak',
      requirements: {'streakDays': 7},
    ),

    // Reading Achievements
    Achievement(
      id: 'bookworm',
      name: 'Bookworm',
      description: 'Complete 10 story books',
      icon: '📚',
      xpReward: 150,
      rarity: 'Epic',
      category: 'Reading',
      requirements: {'booksCompleted': 10},
    ),
    Achievement(
      id: 'scholar',
      name: 'Scholar',
      description: 'Read 5 full textbooks',
      icon: '🎓',
      xpReward: 200,
      rarity: 'Legendary',
      category: 'Reading',
      requirements: {'textbooksRead': 5},
    ),

    // Speed Achievements
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Answer 100 questions in one day',
      icon: '⚡',
      xpReward: 100,
      rarity: 'Rare',
      category: 'Speed',
      requirements: {'questionsInDay': 100},
    ),

    // Perfect Score Achievements
    Achievement(
      id: 'perfect_storm',
      name: 'Perfect Storm',
      description: 'Achieve 10 perfect scores',
      icon: '🏆',
      xpReward: 150,
      rarity: 'Epic',
      category: 'Perfect Scores',
      requirements: {'perfectScores': 10},
    ),

    // First Timer Achievements
    Achievement(
      id: 'first_timer',
      name: 'First Timer',
      description: 'Start your first quiz',
      icon: '🌟',
      xpReward: 10,
      rarity: 'Common',
      category: 'First Steps',
      requirements: {'quizzesCompleted': 1},
    ),

    // Master Explorer
    Achievement(
      id: 'master_explorer',
      name: 'Master Explorer',
      description: 'Complete all 12 trivia categories',
      icon: '👑',
      xpReward: 100,
      rarity: 'Legendary',
      category: 'Trivia',
      requirements: {'triviaCategories': 12},
    ),

    // Subject Champions
    Achievement(
      id: 'subject_champion_math',
      name: 'Math Champion',
      description: 'Top 10 in Mathematics',
      icon: '🎯',
      xpReward: 100,
      rarity: 'Epic',
      category: 'Subject',
      requirements: {'subject': 'Mathematics', 'topRank': 10},
    ),

    // Tier Achievements
    Achievement(
      id: 'diamond_tier',
      name: 'Diamond Tier',
      description: 'Reach Diamond tier (5000 XP)',
      icon: '💎',
      xpReward: 500,
      rarity: 'Legendary',
      category: 'Tier',
      requirements: {'xpRequired': 5000},
    ),

    // Volume Achievements
    Achievement(
      id: 'century_club',
      name: 'Century Club',
      description: 'Answer 100 questions correctly',
      icon: '💯',
      xpReward: 50,
      rarity: 'Rare',
      category: 'Volume',
      requirements: {'correctAnswers': 100},
    ),
    Achievement(
      id: 'grand_master',
      name: 'Grand Master',
      description: 'Answer 1000 questions correctly',
      icon: '🏅',
      xpReward: 300,
      rarity: 'Legendary',
      category: 'Volume',
      requirements: {'correctAnswers': 1000},
    ),

    // Consistency Achievements
    Achievement(
      id: 'consistent_learner',
      name: 'Consistent Learner',
      description: 'Complete at least 1 quiz every day for a week',
      icon: '📅',
      xpReward: 75,
      rarity: 'Rare',
      category: 'Consistency',
      requirements: {'dailyQuizStreak': 7},
    ),
  ];

  /// Check and award achievements for a user
  Future<List<Achievement>> checkAndAwardAchievements(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final earnedAchievements = (userData?['achievements'] as List<dynamic>?) ?? [];

      List<Achievement> newlyEarned = [];

      // Get user stats
      final stats = await _getUserStats(userId);

      for (final achievement in allAchievements) {
        // Skip if already earned
        if (earnedAchievements.contains(achievement.id)) {
          continue;
        }

        // Check requirements
        bool earned = false;

        switch (achievement.id) {
          case 'accuracy_master':
            earned = stats['totalQuestions'] >= achievement.requirements['questionsRequired'] &&
                stats['accuracy'] >= achievement.requirements['accuracyThreshold'];
            break;
          
          case 'perfectionist':
          case 'perfect_storm':
            earned = stats['perfectScores'] >= achievement.requirements['perfectScores'];
            break;
          
          case 'streak_champion':
          case 'week_warrior':
            earned = stats['currentStreak'] >= achievement.requirements['streakDays'];
            break;
          
          case 'bookworm':
            earned = stats['booksCompleted'] >= achievement.requirements['booksCompleted'];
            break;
          
          case 'scholar':
            earned = stats['textbooksRead'] >= achievement.requirements['textbooksRead'];
            break;
          
          case 'speed_demon':
            earned = await _checkQuestionsInDay(userId, achievement.requirements['questionsInDay']);
            break;
          
          case 'first_timer':
            earned = stats['quizzesCompleted'] >= achievement.requirements['quizzesCompleted'];
            break;
          
          case 'master_explorer':
            final completedTrivia = await XPService().getCompletedTriviaCategoriesCount(userId);
            earned = completedTrivia >= achievement.requirements['triviaCategories'];
            break;
          
          case 'diamond_tier':
            earned = stats['totalXP'] >= achievement.requirements['xpRequired'];
            break;
          
          case 'century_club':
          case 'grand_master':
            earned = stats['totalCorrect'] >= achievement.requirements['correctAnswers'];
            break;
          
          case 'consistent_learner':
            earned = await _checkDailyQuizStreak(userId, achievement.requirements['dailyQuizStreak']);
            break;
        }

        if (earned) {
          await _awardAchievement(userId, achievement);
          newlyEarned.add(achievement);
        }
      }

      return newlyEarned;
    } catch (e) {
      print('Error checking achievements: $e');
      return [];
    }
  }

  /// Award an achievement to a user
  Future<void> _awardAchievement(String userId, Achievement achievement) async {
    try {
      // Add to user's achievements
      await _firestore.collection('users').doc(userId).update({
        'achievements': FieldValue.arrayUnion([achievement.id]),
        'achievementDates.${achievement.id}': FieldValue.serverTimestamp(),
      });

      // Award XP
      await XPService().recordAchievementXP(
        userId: userId,
        achievementId: achievement.id,
        achievementName: achievement.name,
        xpAmount: achievement.xpReward,
      );

      print('🏆 Achievement Unlocked: ${achievement.name} (+${achievement.xpReward} XP)');
    } catch (e) {
      print('Error awarding achievement: $e');
    }
  }

  /// Get user statistics for achievement checking
  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      final quizSnapshot = await _firestore
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get();

      int totalQuestions = 0;
      int totalCorrect = 0;
      int perfectScores = 0;
      int quizzesCompleted = quizSnapshot.docs.length;

      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        final correct = (data['correctAnswers'] as int?) ?? 0;
        final total = (data['totalQuestions'] as int?) ?? 0;
        final percentage = (data['percentage'] as num?)?.toDouble() ?? 0.0;

        totalQuestions += total;
        totalCorrect += correct;
        if (percentage == 100.0) {
          perfectScores++;
        }
      }

      return {
        'totalXP': (userData?['totalXP'] as int?) ?? 0,
        'totalQuestions': totalQuestions,
        'totalCorrect': totalCorrect,
        'accuracy': totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0,
        'perfectScores': perfectScores,
        'quizzesCompleted': quizzesCompleted,
        'currentStreak': 0, // TODO: Calculate from login data
        'booksCompleted': 0, // TODO: Track from reading
        'textbooksRead': 0, // TODO: Track from reading
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  /// Check if user answered X questions in one day
  Future<bool> _checkQuestionsInDay(String userId, int required) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final quizSnapshot = await _firestore
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      int questionsToday = 0;
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        questionsToday += (data['totalQuestions'] as int?) ?? 0;
      }

      return questionsToday >= required;
    } catch (e) {
      print('Error checking questions in day: $e');
      return false;
    }
  }

  /// Check daily quiz streak
  Future<bool> _checkDailyQuizStreak(String userId, int required) async {
    try {
      // TODO: Implement proper streak tracking
      // For now, return false
      return false;
    } catch (e) {
      print('Error checking daily quiz streak: $e');
      return false;
    }
  }

  /// Get user's earned achievements
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final earnedIds = (userDoc.data()?['achievements'] as List<dynamic>?) ?? [];

      return allAchievements.where((a) => earnedIds.contains(a.id)).toList();
    } catch (e) {
      print('Error getting user achievements: $e');
      return [];
    }
  }

  /// Get locked achievements with progress
  Future<List<Map<String, dynamic>>> getLockedAchievements(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final earnedIds = (userDoc.data()?['achievements'] as List<dynamic>?) ?? [];

      final stats = await _getUserStats(userId);
      List<Map<String, dynamic>> locked = [];

      for (final achievement in allAchievements) {
        if (earnedIds.contains(achievement.id)) continue;

        double progress = 0.0;
        String progressText = '';

        switch (achievement.id) {
          case 'accuracy_master':
            final questionsProgress = stats['totalQuestions'] / achievement.requirements['questionsRequired'];
            progress = questionsProgress.clamp(0.0, 1.0);
            progressText = '${stats['totalQuestions']}/${achievement.requirements['questionsRequired']} questions at 95%+ accuracy';
            break;
          
          case 'century_club':
          case 'grand_master':
            progress = (stats['totalCorrect'] / achievement.requirements['correctAnswers']).clamp(0.0, 1.0);
            progressText = '${stats['totalCorrect']}/${achievement.requirements['correctAnswers']} correct answers';
            break;
          
          case 'perfect_storm':
          case 'perfectionist':
            progress = (stats['perfectScores'] / achievement.requirements['perfectScores']).clamp(0.0, 1.0);
            progressText = '${stats['perfectScores']}/${achievement.requirements['perfectScores']} perfect scores';
            break;
          
          default:
            progressText = 'Keep working on it!';
        }

        locked.add({
          'achievement': achievement,
          'progress': progress,
          'progressText': progressText,
        });
      }

      return locked;
    } catch (e) {
      print('Error getting locked achievements: $e');
      return [];
    }
  }

  /// Get rarity color
  Color getRarityColor(String rarity) {
    switch (rarity) {
      case 'Common':
        return const Color(0xFF6B7280); // Gray
      case 'Rare':
        return const Color(0xFF3B82F6); // Blue
      case 'Epic':
        return const Color(0xFF8B5CF6); // Purple
      case 'Legendary':
        return const Color(0xFFFFD700); // Gold
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// Extension for XPService to record achievement XP
extension AchievementXP on XPService {
  Future<void> recordAchievementXP({
    required String userId,
    required String achievementId,
    required String achievementName,
    required int xpAmount,
  }) async {
    await FirebaseFirestore.instance.collection('xp_transactions').add({
      'userId': userId,
      'xpAmount': xpAmount,
      'source': 'achievement',
      'sourceId': achievementId,
      'details': {
        'achievementName': achievementName,
      },
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'totalXP': FieldValue.increment(xpAmount),
      'lastXPUpdate': FieldValue.serverTimestamp(),
    });
  }
}
