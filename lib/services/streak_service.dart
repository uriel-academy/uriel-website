import 'package:cloud_firestore/cloud_firestore.dart';
import 'xp_service.dart';
import 'notification_service.dart';

import 'package:flutter/foundation.dart';
class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record daily activity and update streak
  Future<Map<String, dynamic>> recordDailyActivity(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
      final currentStreak = (data?['currentStreak'] as int?) ?? 0;
      final longestStreak = (data?['longestStreak'] as int?) ?? 0;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastActivityTimestamp == null) {
        // First time user
        await _firestore.collection('users').doc(userId).update({
          'lastActivityDate': Timestamp.fromDate(today),
          'currentStreak': 1,
          'longestStreak': 1,
          'totalActiveDays': 1,
        });
        
        // Award daily login XP
        await XPService().recordDailyLogin(userId);
        
        return {
          'newStreak': 1,
          'xpEarned': XPService.DAILY_LOGIN_BONUS,
          'message': '🎉 Welcome! Your learning journey begins!',
        };
      }
      
      final lastActivity = lastActivityTimestamp.toDate();
      final lastActivityDay = DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
      
      // Check if already logged in today
      if (lastActivityDay.year == today.year &&
          lastActivityDay.month == today.month &&
          lastActivityDay.day == today.day) {
        return {
          'newStreak': currentStreak,
          'xpEarned': 0,
          'message': '✅ Already logged in today!',
        };
      }
      
      final daysSinceLastActivity = today.difference(lastActivityDay).inDays;
      
      int newStreak;
      String message;
      int xpBonus = XPService.DAILY_LOGIN_BONUS;
      
      if (daysSinceLastActivity == 1) {
        // Consecutive day - streak continues
        newStreak = currentStreak + 1;
        
        // Bonus XP for longer streaks
        if (newStreak >= 30) {
          xpBonus += 30; // +30 XP for 30+ day streak
          message = '🔥 Incredible $newStreak-day streak! +$xpBonus XP!';
        } else if (newStreak >= 14) {
          xpBonus += 15; // +15 XP for 14+ day streak
          message = '⚡ Amazing $newStreak-day streak! +$xpBonus XP!';
        } else if (newStreak >= 7) {
          xpBonus += 10; // +10 XP for 7+ day streak
          message = '🌟 Week streak! $newStreak days! +$xpBonus XP!';
        } else if (newStreak >= 3) {
          xpBonus += 5; // +5 XP for 3+ day streak
          message = '💪 $newStreak-day streak! +$xpBonus XP!';
        } else {
          message = '🎯 $newStreak days in a row! +$xpBonus XP!';
        }
      } else {
        // Streak broken
        if (currentStreak > 0) {
          message = '💔 Streak broken. Starting fresh! +$xpBonus XP';
        } else {
          message = '🚀 Welcome back! +$xpBonus XP';
        }
        newStreak = 1;
      }
      
      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;
      final totalActiveDays = (data?['totalActiveDays'] as int?) ?? 0 + 1;
      
      // Update user data
      await _firestore.collection('users').doc(userId).update({
        'lastActivityDate': Timestamp.fromDate(today),
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'totalActiveDays': totalActiveDays,
      });
      
      // Award XP
      await _firestore.collection('xp_transactions').add({
        'userId': userId,
        'xpAmount': xpBonus,
        'source': 'daily_login',
        'sourceId': 'streak_${now.millisecondsSinceEpoch}',
        'details': {
          'streak': newStreak,
          'date': today.toIso8601String(),
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('users').doc(userId).update({
        'totalXP': FieldValue.increment(xpBonus),
        'lastXPUpdate': FieldValue.serverTimestamp(),
      });
      
      return {
        'newStreak': newStreak,
        'xpEarned': xpBonus,
        'message': message,
        'streakBroken': daysSinceLastActivity > 1,
      };
    } catch (e) {
      debugPrint('Error recording daily activity: $e');
      return {
        'newStreak': 0,
        'xpEarned': 0,
        'message': 'Error recording activity',
      };
    }
  }

  /// Check if user should be warned about losing streak
  Future<void> checkStreakRisk(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
      final currentStreak = (data?['currentStreak'] as int?) ?? 0;
      
      if (lastActivityTimestamp == null || currentStreak == 0) return;
      
      final lastActivity = lastActivityTimestamp.toDate();
      final now = DateTime.now();
      final hoursSinceActivity = now.difference(lastActivity).inHours;
      
      // Warn if 20+ hours since last activity and has active streak
      if (hoursSinceActivity >= 20 && currentStreak >= 3) {
        await NotificationService().notifyStreakRisk(
          userId: userId,
          streakDays: currentStreak,
        );
      }
    } catch (e) {
      debugPrint('Error checking streak risk: $e');
    }
  }

  /// Get user's current streak
  Future<int> getCurrentStreak(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['currentStreak'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting current streak: $e');
      return 0;
    }
  }

  /// Get user's longest streak
  Future<int> getLongestStreak(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['longestStreak'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting longest streak: $e');
      return 0;
    }
  }

  /// Get streak statistics
  Future<Map<String, int>> getStreakStats(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      return {
        'current': (data?['currentStreak'] as int?) ?? 0,
        'longest': (data?['longestStreak'] as int?) ?? 0,
        'totalDays': (data?['totalActiveDays'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting streak stats: $e');
      return {'current': 0, 'longest': 0, 'totalDays': 0};
    }
  }

  /// Check if user is at risk of losing streak (for UI display)
  Future<bool> isStreakAtRisk(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastActivityTimestamp = data?['lastActivityDate'] as Timestamp?;
      final currentStreak = (data?['currentStreak'] as int?) ?? 0;
      
      if (lastActivityTimestamp == null || currentStreak == 0) return false;
      
      final lastActivity = lastActivityTimestamp.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastActivityDay = DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
      
      // Already logged in today - safe
      if (lastActivityDay.year == today.year &&
          lastActivityDay.month == today.month &&
          lastActivityDay.day == today.day) {
        return false;
      }
      
      // Check if 20+ hours since last activity
      final hoursSinceActivity = now.difference(lastActivity).inHours;
      return hoursSinceActivity >= 20;
    } catch (e) {
      debugPrint('Error checking streak risk: $e');
      return false;
    }
  }
}
