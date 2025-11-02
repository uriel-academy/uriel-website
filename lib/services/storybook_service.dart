import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/storybook_model.dart';

class StorybookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all active storybooks from Firestore
  Future<List<Storybook>> getStorybooks() async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .orderBy('title')
          .get();

      return snapshot.docs
          .map((doc) => Storybook.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching storybooks: $e');
      return [];
    }
  }

  /// Get storybooks by category
  Future<List<Storybook>> getStorybooksByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .orderBy('title')
          .get();

      return snapshot.docs
          .map((doc) => Storybook.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching storybooks by category: $e');
      return [];
    }
  }

  /// Get storybooks by author
  Future<List<Storybook>> getStorybooksByAuthor(String author) async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .where('author', isEqualTo: author)
          .orderBy('title')
          .get();

      return snapshot.docs
          .map((doc) => Storybook.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching storybooks by author: $e');
      return [];
    }
  }

  /// Search storybooks by title or author
  Future<List<Storybook>> searchStorybooks(String query) async {
    try {
      // Get all active storybooks
      final allBooks = await getStorybooks();
      
      // Filter by search query (case-insensitive)
      final searchLower = query.toLowerCase();
      return allBooks.where((book) {
        return book.title.toLowerCase().contains(searchLower) ||
            book.author.toLowerCase().contains(searchLower);
      }).toList();
    } catch (e) {
      debugPrint('Error searching storybooks: $e');
      return [];
    }
  }

  /// Increment read count for a storybook
  Future<void> incrementReadCount(String storybookId) async {
    try {
      await _firestore.collection('storybooks').doc(storybookId).update({
        'readCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing read count: $e');
    }
  }

  /// Get featured/popular storybooks (top 10 by read count)
  Future<List<Storybook>> getFeaturedStorybooks({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .orderBy('readCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Storybook.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching featured storybooks: $e');
      return [];
    }
  }

  /// Get new releases (added in last 30 days)
  Future<List<Storybook>> getNewReleases() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final snapshot = await _firestore
          .collection('storybooks')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Storybook.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching new releases: $e');
      return [];
    }
  }

  /// Get unique authors list
  Future<List<String>> getAuthors() async {
    try {
      final books = await getStorybooks();
      final authors = books.map((book) => book.author).toSet().toList();
      authors.sort();
      return authors;
    } catch (e) {
      debugPrint('Error fetching authors: $e');
      return [];
    }
  }

  /// Get unique categories list
  Future<List<String>> getCategories() async {
    try {
      final books = await getStorybooks();
      final categories = books.map((book) => book.category).toSet().toList();
      categories.sort();
      return categories;
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  /// Get recommended books based on the current book
  /// Returns books by same author, then same category
  Future<List<Storybook>> getRecommendedBooks(Storybook currentBook, {int limit = 6}) async {
    try {
      final recommendations = <Storybook>[];
      
      // 1. Get other books by the same author
      final sameAuthorBooks = await getStorybooksByAuthor(currentBook.author);
      recommendations.addAll(
        sameAuthorBooks.where((book) => book.id != currentBook.id)
      );
      
      // 2. If we need more, get books from same category
      if (recommendations.length < limit) {
        final sameCategoryBooks = await getStorybooksByCategory(currentBook.category);
        for (var book in sameCategoryBooks) {
          if (book.id != currentBook.id && 
              !recommendations.any((r) => r.id == book.id)) {
            recommendations.add(book);
          }
          if (recommendations.length >= limit) break;
        }
      }
      
      // 3. If still need more, get popular books
      if (recommendations.length < limit) {
        final popularBooks = await getFeaturedStorybooks(limit: 10);
        for (var book in popularBooks) {
          if (book.id != currentBook.id && 
              !recommendations.any((r) => r.id == book.id)) {
            recommendations.add(book);
          }
          if (recommendations.length >= limit) break;
        }
      }
      
      return recommendations.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching recommended books: $e');
      return [];
    }
  }

  /// Get related books (same author or category) for "You May Also Like" section
  Future<List<Storybook>> getRelatedBooks(String storybookId, {int limit = 4}) async {
    try {
      // Get the current book
      final doc = await _firestore.collection('storybooks').doc(storybookId).get();
      if (!doc.exists) return [];
      
      final currentBook = Storybook.fromFirestore(doc);
      return getRecommendedBooks(currentBook, limit: limit);
    } catch (e) {
      debugPrint('Error fetching related books: $e');
      return [];
    }
  }
}
