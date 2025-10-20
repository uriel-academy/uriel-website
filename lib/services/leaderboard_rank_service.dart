import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for Leaderboard Rank
class LeaderboardRank {
  final int rank;
  final String name;
  final int minXP;
  final int maxXP;
  final String tier;
  final String tierTheme;
  final String description;
  final String achievements;
  final String psychology;
  final String meaning;
  final Color color;
  final String visualTheme;
  final String imageUrl;
  final bool isUltimate;

  LeaderboardRank({
    required this.rank,
    required this.name,
    required this.minXP,
    required this.maxXP,
    required this.tier,
    required this.tierTheme,
    required this.description,
    this.achievements = '',
    this.psychology = '',
    this.meaning = '',
    required this.color,
    this.visualTheme = '',
    required this.imageUrl,
    this.isUltimate = false,
  });

  factory LeaderboardRank.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardRank(
      rank: data['rank'] ?? 0,
      name: data['name'] ?? '',
      minXP: data['minXP'] ?? 0,
      maxXP: data['maxXP'] ?? 0,
      tier: data['tier'] ?? '',
      tierTheme: data['tierTheme'] ?? '',
      description: data['description'] ?? '',
      achievements: data['achievements'] ?? '',
      psychology: data['psychology'] ?? '',
      meaning: data['meaning'] ?? '',
      color: _parseColor(data['color'] ?? '#4CAF50'),
      visualTheme: data['visualTheme'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      isUltimate: data['isUltimate'] ?? false,
    );
  }

  static Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return const Color(0xFF4CAF50); // Default green
    }
  }

  /// Get XP needed to reach next rank
  int getXPToNextRank(int currentXP) {
    return maxXP - currentXP + 1;
  }

  /// Get progress percentage within current rank
  double getProgressInRank(int currentXP) {
    if (currentXP < minXP) return 0.0;
    if (currentXP > maxXP) return 1.0;
    
    final totalXPInRank = maxXP - minXP + 1;
    final earnedInRank = currentXP - minXP;
    return earnedInRank / totalXPInRank;
  }

  /// Get tier color based on tier name
  Color getTierColor() {
    switch (tier.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF4CAF50); // Green
      case 'achiever':
        return const Color(0xFFFF9800); // Orange/Bronze
      case 'advanced':
        return const Color(0xFF673AB7); // Purple
      case 'expert':
        return const Color(0xFF2196F3); // Blue
      case 'prestige':
        return const Color(0xFFAB47BC); // Violet
      case 'supreme':
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.grey;
    }
  }

  /// Get tier icon
  IconData getTierIcon() {
    switch (tier.toLowerCase()) {
      case 'beginner':
        return Icons.emoji_events_outlined;
      case 'achiever':
        return Icons.military_tech_outlined;
      case 'advanced':
        return Icons.workspace_premium_outlined;
      case 'expert':
        return Icons.stars_outlined;
      case 'prestige':
        return Icons.diamond_outlined;
      case 'supreme':
        return Icons.auto_awesome;
      default:
        return Icons.emoji_events;
    }
  }
}

/// Service to manage leaderboard ranks
class LeaderboardRankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for rank ranges (lightweight data for client-side calculation)
  List<LeaderboardRank>? _cachedRanks;

  /// Get user's current rank based on XP with retry logic
  Future<LeaderboardRank?> getUserRank(int userXP) async {
    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Try to use cache first
        if (_cachedRanks != null && _cachedRanks!.isNotEmpty) {
          return _getRankFromCache(userXP);
        }

        // Load all ranks and filter client-side (avoids complex Firestore query)
        await cacheRankRanges();
        
        if (_cachedRanks != null && _cachedRanks!.isNotEmpty) {
          return _getRankFromCache(userXP);
        }

        // Fallback: Get the first rank (Learner)
        final fallbackSnapshot = await _firestore
            .collection('leaderboardRanks')
            .doc('rank_1')
            .get();

        if (fallbackSnapshot.exists) {
          return LeaderboardRank.fromFirestore(fallbackSnapshot);
        }

        return null;
      } catch (e) {
        debugPrint('❌ Error getting user rank (attempt $attempt/$maxRetries): $e');
        if (attempt == maxRetries) {
          // Return a default rank on final failure
          return LeaderboardRank(
            rank: 1,
            name: 'Learner',
            minXP: 0,
            maxXP: 100,
            tier: 'Beginner',
            tierTheme: 'Getting Started',
            description: 'Welcome to your learning journey!',
            color: const Color(0xFF4CAF50),
            imageUrl: '',
          );
        }
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return null;
  }

  /// Get next rank based on current XP
  Future<LeaderboardRank?> getNextRank(int userXP) async {
    try {
      // Get current rank first
      final currentRank = await getUserRank(userXP);
      if (currentRank == null) return null;

      // Query for next rank
      final snapshot = await _firestore
          .collection('leaderboardRanks')
          .where('rank', isEqualTo: currentRank.rank + 1)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return LeaderboardRank.fromFirestore(snapshot.docs.first);
      }

      return null; // User is at max rank
    } catch (e) {
      debugPrint('Error getting next rank: $e');
      return null;
    }
  }

  /// Get all ranks (for displaying rank progression) with retry logic
  Future<List<LeaderboardRank>> getAllRanks() async {
    const int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final snapshot = await _firestore
            .collection('leaderboardRanks')
            .orderBy('rank')
            .get();

        return snapshot.docs
            .map((doc) => LeaderboardRank.fromFirestore(doc))
            .toList();
      } catch (e) {
        debugPrint('Error getting all ranks (attempt $attempt/$maxRetries): $e');
        if (attempt == maxRetries) {
          // Return empty list on final failure
          return [];
        }
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return [];
  }

  /// Load and cache rank ranges for fast lookup
  Future<void> cacheRankRanges() async {
    try {
      _cachedRanks = await getAllRanks();
      debugPrint('✅ Cached ${_cachedRanks?.length ?? 0} ranks');
    } catch (e) {
      debugPrint('Error caching rank ranges: $e');
    }
  }

  /// Get rank from cache (faster than Firestore query)
  LeaderboardRank? _getRankFromCache(int userXP) {
    if (_cachedRanks == null) return null;

    for (final rank in _cachedRanks!) {
      if (userXP >= rank.minXP && userXP <= rank.maxXP) {
        return rank;
      }
    }

    return _cachedRanks?.first; // Default to first rank
  }

  /// Get specific rank by number
  Future<LeaderboardRank?> getRankByNumber(int rankNumber) async {
    try {
      final doc = await _firestore
          .collection('leaderboardRanks')
          .doc('rank_$rankNumber')
          .get();

      if (doc.exists) {
        return LeaderboardRank.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting rank $rankNumber: $e');
      return null;
    }
  }

  /// Get ranks by tier
  Future<List<LeaderboardRank>> getRanksByTier(String tier) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboardRanks')
          .where('tier', isEqualTo: tier)
          .orderBy('rank')
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardRank.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting ranks for tier $tier: $e');
      return [];
    }
  }

  /// Get leaderboard metadata
  Future<Map<String, dynamic>?> getLeaderboardMetadata() async {
    try {
      final doc = await _firestore
          .collection('leaderboardMetadata')
          .doc('ranks_info')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting leaderboard metadata: $e');
      return null;
    }
  }

  /// Calculate XP for rank achievement notification
  bool shouldShowRankUpNotification(int oldXP, int newXP, LeaderboardRank currentRank) {
    return oldXP < currentRank.minXP && newXP >= currentRank.minXP;
  }

  /// Get congratulations message for new rank
  String getRankUpMessage(LeaderboardRank rank) {
    final messages = {
      'Beginner': 'Welcome to your learning journey! 🌱',
      'Achiever': 'Your consistency is paying off! 🏆',
      'Advanced': 'You\'re becoming a master! ⚡',
      'Expert': 'Excellence is your standard! 💎',
      'Prestige': 'You\'ve entered legendary territory! 🌟',
      'Supreme': 'You\'re an inspiration to all! 👑',
    };

    return messages[rank.tier] ?? 'Congratulations on your achievement! 🎉';
  }

  /// Format XP with thousand separators
  String formatXP(int xp) {
    return xp.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
