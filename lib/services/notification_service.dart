import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a rank change notification
  Future<void> notifyRankChange({
    required String userId,
    required int oldRank,
    required int newRank,
    required int xpGained,
  }) async {
    try {
      final change = newRank - oldRank;
      String message;
      String type;

      if (change < 0) {
        // Moved up (better rank)
        message = '🎉 You moved up ${change.abs()} ${change.abs() == 1 ? 'spot' : 'spots'} to rank #$newRank!';
        type = 'rank_up';
      } else if (change > 0) {
        // Moved down (worse rank)
        message = '⚠️ You dropped $change ${change == 1 ? 'spot' : 'spots'} to rank #$newRank. Time to study!';
        type = 'rank_down';
      } else {
        return; // No change
      }

      await _createNotification(
        userId: userId,
        message: message,
        type: type,
        data: {
          'oldRank': oldRank,
          'newRank': newRank,
          'xpGained': xpGained,
        },
      );
    } catch (e) {
      debugPrint('Error notifying rank change: $e');
    }
  }

  /// Notify user they're close to a milestone
  Future<void> notifyMilestone({
    required String userId,
    required String milestone,
    required int progress,
    required int target,
  }) async {
    try {
      String message;
      
      if (milestone == 'top10') {
        message = '⚡ You\'re only ${target - progress} spots away from Top 10!';
      } else if (milestone == 'top50') {
        message = '🌟 You\'re only ${target - progress} spots away from Top 50!';
      } else if (milestone == 'next_tier') {
        message = '🔥 Only ${target - progress} XP until next tier!';
      } else {
        return;
      }

      await _createNotification(
        userId: userId,
        message: message,
        type: 'milestone_progress',
        data: {
          'milestone': milestone,
          'progress': progress,
          'target': target,
        },
      );
    } catch (e) {
      debugPrint('Error notifying milestone: $e');
    }
  }

  /// Notify when someone passes the user
  Future<void> notifySomeonePassed({
    required String userId,
    required String passerName,
  }) async {
    try {
      await _createNotification(
        userId: userId,
        message: '👀 $passerName just passed you on the leaderboard!',
        type: 'someone_passed',
        data: {'passerName': passerName},
      );
    } catch (e) {
      debugPrint('Error notifying someone passed: $e');
    }
  }

  /// Notify about friend challenge
  Future<void> notifyFriendChallenge({
    required String userId,
    required String challengerId,
    required String challengerName,
    required String subject,
  }) async {
    try {
      await _createNotification(
        userId: userId,
        message: '⚔️ $challengerName challenged you to a $subject quiz!',
        type: 'friend_challenge',
        data: {
          'challengerId': challengerId,
          'challengerName': challengerName,
          'subject': subject,
        },
      );
    } catch (e) {
      debugPrint('Error notifying friend challenge: $e');
    }
  }

  /// Notify about streak risk
  Future<void> notifyStreakRisk({
    required String userId,
    required int streakDays,
  }) async {
    try {
      await _createNotification(
        userId: userId,
        message: '🔥 Don\'t break your $streakDays-day streak! Study today to keep it going.',
        type: 'streak_risk',
        data: {'streakDays': streakDays},
      );
    } catch (e) {
      debugPrint('Error notifying streak risk: $e');
    }
  }

  /// Create a notification
  Future<void> _createNotification({
    required String userId,
    required String message,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'message': message,
        'type': type,
        'data': data,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  /// Get user's unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get user's notifications
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Check and send daily engagement notifications
  Future<void> checkDailyEngagement(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastActivityDate = (data?['lastActivityDate'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      
      if (lastActivityDate != null) {
        final daysSinceActivity = now.difference(lastActivityDate).inDays;
        
        // Welcome back notifications
        if (daysSinceActivity >= 3 && daysSinceActivity < 7) {
          await _createNotification(
            userId: userId,
            message: '👋 We missed you! Come back and continue your learning journey.',
            type: 'comeback',
            data: {'daysSinceActivity': daysSinceActivity},
          );
        } else if (daysSinceActivity >= 7) {
          final totalXP = (data?['totalXP'] as int?) ?? 0;
          await _createNotification(
            userId: userId,
            message: '🎁 Welcome back! You still have $totalXP XP. Let\'s get back on track!',
            type: 'comeback',
            data: {'daysSinceActivity': daysSinceActivity, 'totalXP': totalXP},
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking daily engagement: $e');
    }
  }
}
