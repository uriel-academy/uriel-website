import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to calculate dynamic, crowd-sourced question difficulty
/// Based on actual student performance data across the platform
class QuestionDifficultyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate crowd-sourced difficulty for a question
  /// Returns a difficulty score between 0.0 (easy) and 1.0 (hard)
  /// 
  /// Formula: difficulty = 1 - successRate
  /// - 90% success → 0.1 difficulty (easy)
  /// - 50% success → 0.5 difficulty (medium)
  /// - 20% success → 0.8 difficulty (hard)
  Future<double> getQuestionDifficulty(String questionId) async {
    try {
      // Query all attempts for this question across all users
      final attemptsQuery = await _firestore
          .collectionGroup('questionAttempts')
          .where('questionId', isEqualTo: questionId)
          .get();

      if (attemptsQuery.docs.isEmpty || attemptsQuery.docs.length < 20) {
        // Not enough data yet - return neutral difficulty
        return 0.5; // Medium difficulty default
      }

      // Calculate success rate
      final correctCount = attemptsQuery.docs
          .where((doc) => doc.data()['isCorrect'] == true)
          .length;
      
      final successRate = correctCount / attemptsQuery.docs.length;

      // Convert to difficulty score (inverse of success rate)
      final difficulty = 1.0 - successRate;

      return difficulty.clamp(0.0, 1.0);
    } catch (e) {
      print('Error calculating question difficulty: $e');
      return 0.5; // Default to medium
    }
  }

  /// Convert difficulty score (0-1) to weight for grade prediction
  /// Easy questions (low difficulty) get lower weight
  /// Hard questions (high difficulty) get higher weight
  double difficultyToWeight(double difficulty) {
    // Map 0.0-1.0 difficulty to 0.7-1.3 weight range
    // This gives harder questions more impact on grade prediction
    return 0.7 + (difficulty * 0.6);
  }

  /// Get difficulty label for display
  String getDifficultyLabel(double difficulty) {
    if (difficulty < 0.3) return 'Easy';
    if (difficulty < 0.6) return 'Medium';
    return 'Hard';
  }

  /// Batch update question difficulties
  /// Run this periodically (e.g., weekly) to refresh difficulty scores
  Future<void> updateAllQuestionDifficulties(String subject) async {
    try {
      // Get all unique question IDs for the subject
      final questionsQuery = await _firestore
          .collectionGroup('questionAttempts')
          .where('subject', isEqualTo: subject)
          .get();

      final questionIds = <String>{};
      for (final doc in questionsQuery.docs) {
        questionIds.add(doc.data()['questionId'] as String);
      }

      // Calculate and store difficulty for each question
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final questionId in questionIds) {
        final difficulty = await getQuestionDifficulty(questionId);
        final weight = difficultyToWeight(difficulty);
        final label = getDifficultyLabel(difficulty);

        // Store in a dedicated collection for quick lookup
        final docRef = _firestore
            .collection('questionDifficulty')
            .doc(questionId);

        batch.set(docRef, {
          'questionId': questionId,
          'difficulty': difficulty,
          'weight': weight,
          'label': label,
          'subject': subject,
          'calculatedAt': FieldValue.serverTimestamp(),
        });

        batchCount++;

        // Commit every 500 operations
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }

      // Commit remaining
      if (batchCount > 0) {
        await batch.commit();
      }

      print('✅ Updated difficulty for ${questionIds.length} questions in $subject');
    } catch (e) {
      print('Error updating question difficulties: $e');
    }
  }

  /// Get cached difficulty from Firebase
  /// Much faster than calculating on-the-fly
  Future<double> getCachedDifficulty(String questionId) async {
    try {
      final doc = await _firestore
          .collection('questionDifficulty')
          .doc(questionId)
          .get();

      if (doc.exists) {
        return (doc.data()?['difficulty'] ?? 0.5) as double;
      }

      // Not cached yet - calculate and cache it
      final difficulty = await getQuestionDifficulty(questionId);
      
      // Cache for future use
      await _firestore.collection('questionDifficulty').doc(questionId).set({
        'questionId': questionId,
        'difficulty': difficulty,
        'weight': difficultyToWeight(difficulty),
        'label': getDifficultyLabel(difficulty),
        'calculatedAt': FieldValue.serverTimestamp(),
      });

      return difficulty;
    } catch (e) {
      print('Error getting cached difficulty: $e');
      return 0.5;
    }
  }

  /// Get difficulty statistics for a subject
  Future<Map<String, dynamic>> getSubjectDifficultyStats(String subject) async {
    try {
      final snapshot = await _firestore
          .collection('questionDifficulty')
          .where('subject', isEqualTo: subject)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'easy': 0,
          'medium': 0,
          'hard': 0,
          'total': 0,
          'avgDifficulty': 0.5,
        };
      }

      int easy = 0, medium = 0, hard = 0;
      double totalDifficulty = 0.0;

      for (final doc in snapshot.docs) {
        final difficulty = (doc.data()['difficulty'] ?? 0.5) as double;
        totalDifficulty += difficulty;

        if (difficulty < 0.3) {
          easy++;
        } else if (difficulty < 0.6) {
          medium++;
        } else {
          hard++;
        }
      }

      return {
        'easy': easy,
        'medium': medium,
        'hard': hard,
        'total': snapshot.docs.length,
        'avgDifficulty': totalDifficulty / snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting subject difficulty stats: $e');
      return {
        'easy': 0,
        'medium': 0,
        'hard': 0,
        'total': 0,
        'avgDifficulty': 0.5,
      };
    }
  }
}
