import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

/// Tracks user activity and updates lastSeen timestamp
class ActivityTracker extends StatefulWidget {
  final Widget child;

  const ActivityTracker({
    super.key,
    required this.child,
  });

  @override
  State<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<ActivityTracker> {
  Timer? _activityTimer;
  DateTime? _lastUpdateTime;
  DateTime? _lastActivityTime;
  static const _updateInterval =
      Duration(seconds: 30); // Check every 30 seconds
  static const _minUpdateInterval =
      Duration(minutes: 1); // Minimum time between Firestore updates
  static const _activityThreshold = Duration(
      seconds: 45); // Consider active if any interaction in last 45 seconds

  @override
  void initState() {
    super.initState();
    _startActivityTracking();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    super.dispose();
  }

  void _startActivityTracking() {
    // Start a timer that checks for activity
    _activityTimer = Timer.periodic(_updateInterval, (_) {
      _updateLastSeenIfActive();
    });
  }

  void _onUserActivity() {
    // Record that user was active
    _lastActivityTime = DateTime.now();
  }

  Future<void> _updateLastSeenIfActive() async {
    // Only update if there was recent activity
    if (_lastActivityTime != null) {
      final now = DateTime.now();
      final timeSinceLastActivity = now.difference(_lastActivityTime!);

      // Check if user is still active
      if (timeSinceLastActivity <= _activityThreshold) {
        // Prevent too frequent updates to Firestore
        if (_lastUpdateTime == null ||
            now.difference(_lastUpdateTime!) >= _minUpdateInterval) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await UserService().updateLastSeen(user.uid);
            _lastUpdateTime = now;
            debugPrint('📍 Updated last seen for user: ${user.uid}');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onUserActivity,
      onPanDown: (_) => _onUserActivity(),
      onSecondaryTap: _onUserActivity,
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: (_) => _onUserActivity(),
        onPointerMove: (_) => _onUserActivity(),
        child: widget.child,
      ),
    );
  }
}
