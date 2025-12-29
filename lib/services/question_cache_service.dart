import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/question_model.dart';

/// Service for caching and retrieving AI-generated answers to student questions
/// Uses semantic similarity to match questions and reduce API costs
class QuestionCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Threshold for semantic similarity (0-1 scale)
  /// Higher = more strict matching, Lower = more lenient matching
  static const double similarityThreshold = 0.85;

  /// Check if a similar question exists in cache
  /// Returns cached answer if similarity >= threshold
  Future<String?> getCachedAnswer({
    required String question,
    Subject? subject,
    double threshold = similarityThreshold,
  }) async {
    try {
      // Call Cloud Function to find similar questions
      final callable = _functions.httpsCallable('findSimilarQuestion');
      final result = await callable.call({
        'question': question,
        'subject': subject?.name,
        'threshold': threshold,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['found'] == true && data['answer'] != null) {
        debugPrint('✅ Cache hit! Similarity: ${data['similarity']}');
        
        // Update usage statistics
        await _incrementCacheHit(data['questionId']);
        
        return data['answer'] as String;
      }

      debugPrint('❌ Cache miss. Will generate new answer.');
      return null;
    } catch (e) {
      debugPrint('Error checking cache: $e');
      return null;
    }
  }

  /// Save a new Q&A pair to cache
  Future<void> cacheAnswer({
    required String question,
    required String answer,
    Subject? subject,
    String? userId,
  }) async {
    try {
      await _firestore.collection('questionCache').add({
        'question': question,
        'answer': answer,
        'subject': subject?.name,
        'questionLowercase': question.toLowerCase().trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId ?? 'anonymous',
        'usageCount': 1,
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Cached new Q&A pair');
    } catch (e) {
      debugPrint('Error caching answer: $e');
    }
  }

  /// Increment usage count when cache hit occurs
  Future<void> _incrementCacheHit(String questionId) async {
    try {
      await _firestore.collection('questionCache').doc(questionId).update({
        'usageCount': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing cache hit: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final snapshot = await _firestore.collection('questionCache').get();
      
      int totalQuestions = snapshot.docs.length;
      int totalUsage = 0;
      Map<String, int> subjectBreakdown = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalUsage += (data['usageCount'] as int? ?? 0);
        
        String subject = data['subject'] ?? 'general';
        subjectBreakdown[subject] = (subjectBreakdown[subject] ?? 0) + 1;
      }
      
      double avgUsagePerQuestion = totalQuestions > 0 
          ? totalUsage / totalQuestions 
          : 0;
      
      return {
        'totalCachedQuestions': totalQuestions,
        'totalCacheHits': totalUsage,
        'averageUsagePerQuestion': avgUsagePerQuestion,
        'subjectBreakdown': subjectBreakdown,
        'estimatedSavings': _calculateSavings(totalUsage),
      };
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }

  /// Calculate estimated cost savings from caching
  Map<String, dynamic> _calculateSavings(int totalCacheHits) {
    // Average cost per API call for Q&A: ~$0.0065
    const double costPerAPICall = 0.0065;
    
    // First usage is always API call, so savings = (hits - cached questions)
    double totalSaved = totalCacheHits * costPerAPICall;
    
    return {
      'totalSavedUSD': totalSaved,
      'totalSavedGHS': totalSaved * 15, // Approximate GHS conversion
      'apiCallsAvoided': totalCacheHits,
    };
  }

  /// Bulk import pre-generated Q&A pairs
  Future<void> bulkImportQuestions(List<Map<String, dynamic>> questions) async {
    try {
      WriteBatch batch = _firestore.batch();
      int count = 0;
      
      for (var q in questions) {
        if (count >= 500) {
          // Firestore batch limit is 500
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
        
        DocumentReference docRef = _firestore.collection('questionCache').doc();
        batch.set(docRef, {
          'question': q['question'],
          'answer': q['answer'],
          'subject': q['subject'],
          'questionLowercase': (q['question'] as String).toLowerCase().trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'bulk_import',
          'usageCount': 0,
          'lastUsedAt': null,
        });
        
        count++;
      }
      
      if (count > 0) {
        await batch.commit();
      }
      
      debugPrint('✅ Bulk imported ${questions.length} Q&A pairs');
    } catch (e) {
      debugPrint('Error bulk importing questions: $e');
      rethrow;
    }
  }

  /// Get most popular cached questions
  Future<List<Map<String, dynamic>>> getMostPopularQuestions({
    int limit = 20,
    Subject? subject,
  }) async {
    try {
      Query query = _firestore.collection('questionCache')
          .orderBy('usageCount', descending: true)
          .limit(limit);
      
      if (subject != null) {
        query = query.where('subject', isEqualTo: subject.name);
      }
      
      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting popular questions: $e');
      return [];
    }
  }
}
