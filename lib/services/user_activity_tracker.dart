import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Service to track user activity and update lastSeen timestamp
class UserActivityTracker {
  static final UserActivityTracker _instance = UserActivityTracker._internal();
  factory UserActivityTracker() => _instance;
  UserActivityTracker._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _activityTimer;
  DateTime? _lastUpdate;

  /// Start tracking user activity
  void startTracking() {
    // Update immediately on start
    _updateLastSeen();

    // Update every 2 minutes while app is active
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _updateLastSeen();
    });
  }

  /// Stop tracking user activity
  void stopTracking() {
    _activityTimer?.cancel();
    _updateLastSeen(); // Final update before stopping
  }

  /// Manually update last seen timestamp
  Future<void> _updateLastSeen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Don't update too frequently (minimum 1 minute between updates)
      final now = DateTime.now();
      if (_lastUpdate != null && 
          now.difference(_lastUpdate!) < const Duration(minutes: 1)) {
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      _lastUpdate = now;
      print('✅ User activity tracked: ${user.uid} at $now');
    } catch (e) {
      print('⚠️ Error updating last seen: $e');
    }
  }

  /// Track a specific user action
  Future<void> trackAction(String action) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('user_actions').add({
        'userId': user.uid,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Also update last seen
      _updateLastSeen();
    } catch (e) {
      print('⚠️ Error tracking action: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _activityTimer?.cancel();
  }
}
