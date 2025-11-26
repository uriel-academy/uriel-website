import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class ContentStrategyService {
  static final ContentStrategyService _instance = ContentStrategyService._internal();
  factory ContentStrategyService() => _instance;
  ContentStrategyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get popular storybooks based on download count
  Future<List<Map<String, dynamic>>> getPopularBooks({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .orderBy('downloadCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting popular books: $e');
      return [];
    }
  }

  /// Get trending books (most downloads in last 30 days)
  Future<List<Map<String, dynamic>>> getTrendingBooks({int limit = 5}) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .where('lastAccessed', isGreaterThan: thirtyDaysAgo)
          .orderBy('lastAccessed', descending: true)
          .orderBy('downloadCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting trending books: $e');
      return [];
    }
  }

  /// Get books by category with popularity ranking
  Future<List<Map<String, dynamic>>> getBooksByCategory(String category, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('downloadCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting books by category: $e');
      return [];
    }
  }

  /// Get recommended books for a user based on their reading history
  Future<List<Map<String, dynamic>>> getRecommendedBooks(String userId, {int limit = 5}) async {
    try {
      // Get user's reading history (this would need to be implemented)
      // For now, return popular books as recommendations
      return await getPopularBooks(limit: limit);
    } catch (e) {
      print('Error getting recommended books: $e');
      return [];
    }
  }

  /// Track content engagement
  Future<void> trackContentEngagement({
    required String bookId,
    required String action,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'content_engagement',
        parameters: {
          'book_id': bookId,
          'action': action,
          'user_id': userId ?? 'anonymous',
          'timestamp': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );
    } catch (e) {
      print('Error tracking content engagement: $e');
    }
  }

  /// Get content performance metrics
  Future<Map<String, dynamic>> getContentMetrics() async {
    try {
      final snapshot = await _firestore.collection('storybooks').get();

      int totalBooks = 0;
      int totalDownloads = 0;
      int activeBooks = 0;
      Map<String, int> categoryStats = {};
      List<Map<String, dynamic>> topPerformers = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalBooks++;

        if (data['isActive'] == true) {
          activeBooks++;
        }

        final downloadCount = (data['downloadCount'] as num?)?.toInt() ?? 0;
        totalDownloads += downloadCount;

        final category = data['category'] ?? 'uncategorized';
        categoryStats[category] = (categoryStats[category] ?? 0) + downloadCount;

        topPerformers.add({
          'id': doc.id,
          'title': data['title'] ?? 'Unknown',
          'downloads': downloadCount,
          'category': category,
        });
      }

      // Sort top performers
      topPerformers.sort((a, b) => b['downloads'].compareTo(a['downloads']));
      topPerformers = topPerformers.take(10).toList();

      return {
        'totalBooks': totalBooks,
        'activeBooks': activeBooks,
        'totalDownloads': totalDownloads,
        'averageDownloadsPerBook': totalBooks > 0 ? (totalDownloads / totalBooks).round() : 0,
        'categoryStats': categoryStats,
        'topPerformers': topPerformers,
      };
    } catch (e) {
      print('Error getting content metrics: $e');
      return {};
    }
  }

  /// Promote books based on performance
  Future<List<String>> getBooksToPromote() async {
    try {
      final metrics = await getContentMetrics();
      final topPerformers = metrics['topPerformers'] as List<Map<String, dynamic>>? ?? [];

      // Get books with high download counts that might need more promotion
      final highPerformingBooks = topPerformers
          .where((book) => book['downloads'] > 5)
          .map((book) => book['id'] as String)
          .toList();

      return highPerformingBooks;
    } catch (e) {
      print('Error getting books to promote: $e');
      return [];
    }
  }

  /// Generate content strategy recommendations
  Future<Map<String, dynamic>> generateContentStrategy() async {
    try {
      final metrics = await getContentMetrics();
      final popularBooks = await getPopularBooks(limit: 20);
      final trendingBooks = await getTrendingBooks(limit: 10);

      return {
        'metrics': metrics,
        'popularBooks': popularBooks,
        'trendingBooks': trendingBooks,
        'recommendations': [
          {
            'type': 'feature_popular',
            'title': 'Feature Popular Books',
            'description': 'Prominently display top 5 most downloaded books on the homepage',
            'books': popularBooks.take(5).toList(),
          },
          {
            'type': 'promote_trending',
            'title': 'Promote Trending Content',
            'description': 'Create a "Trending Now" section with recently popular books',
            'books': trendingBooks,
          },
          {
            'type': 'category_focus',
            'title': 'Focus on High-Performing Categories',
            'description': 'Invest more in categories with highest engagement',
            'categories': (metrics['categoryStats'] as Map<String, int>? ?? {})
                .entries
                .where((entry) => entry.value > 10)
                .map((entry) => entry.key)
                .toList(),
          },
          {
            'type': 'user_personalization',
            'title': 'Implement Personalized Recommendations',
            'description': 'Show recommended books based on user reading patterns',
            'priority': 'high',
          },
        ],
      };
    } catch (e) {
      print('Error generating content strategy: $e');
      return {};
    }
  }
}
