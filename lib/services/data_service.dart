import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Simple Data Service for basic caching and data fetching
/// Replaces the over-engineered ScalabilityService with clean, maintainable code
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  /// Get dashboard data with simple caching
  Future<Map<String, dynamic>?> getDashboardData({
    bool forceRefresh = false,
    Duration? maxAge,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final cacheKey = 'dashboard_${user.uid}';
    final cacheAge = maxAge ?? _defaultCacheDuration;

    // Return cached data if valid
    if (!forceRefresh &&
        _isCacheValid(cacheKey, cacheAge) &&
        _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      // Simple Firestore query - no complex polling
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final statsDoc = await FirebaseFirestore.instance
          .collection('user_stats')
          .doc(user.uid)
          .get();

      final data = {
        'user': userDoc.data(),
        'stats': statsDoc.data(),
        'timestamp': DateTime.now(),
      };

      // Cache the result
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return data;
    } catch (e) {
      print('Error fetching dashboard data: $e');
      // Return cached data if available, even if expired
      return _cache[cacheKey];
    }
  }

  /// Get leaderboard data with simple caching
  Future<List<Map<String, dynamic>>> getLeaderboardData({
    bool forceRefresh = false,
    int limit = 50,
  }) async {
    const cacheKey = 'leaderboard';
    const cacheAge = Duration(minutes: 5);

    // Return cached data if valid
    if (!forceRefresh &&
        _isCacheValid(cacheKey, cacheAge) &&
        _cache.containsKey(cacheKey)) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]);
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('leaderboard')
          .orderBy('totalXP', descending: true)
          .limit(limit)
          .get();

      final data = snapshot.docs.map((doc) => doc.data()).toList();

      // Cache the result
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return data;
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      return _cache[cacheKey] ?? [];
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final cacheKey = 'profile_$userId';

    if (_isCacheValid(cacheKey, _defaultCacheDuration) &&
        _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _cache[cacheKey] = data;
        _cacheTimestamps[cacheKey] = DateTime.now();
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Get questions for a subject
  Future<List<Map<String, dynamic>>> getQuestions({
    required String subject,
    int limit = 20,
    String? difficulty,
  }) async {
    final cacheKey = 'questions_${subject}_${difficulty ?? 'all'}';

    if (_isCacheValid(cacheKey, _defaultCacheDuration) &&
        _cache.containsKey(cacheKey)) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]);
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('questions')
          .where('subject', isEqualTo: subject)
          .limit(limit);

      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query.get();
      final data = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return data;
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }

  /// Clear cache for specific key or all cache
  void clearCache({String? key}) {
    if (key != null) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    } else {
      _cache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Check if cache entry is still valid
  bool _isCacheValid(String key, Duration maxAge) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < maxAge;
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'cacheTimestamps': _cacheTimestamps.length,
    };
  }

  /// Cleanup old cache entries
  void cleanupOldCache({Duration maxAge = const Duration(hours: 1)}) {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > maxAge) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
}
