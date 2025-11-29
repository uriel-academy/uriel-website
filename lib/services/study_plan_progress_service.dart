import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to track student study plan progress across different features
class StudyPlanProgressService {
  static final StudyPlanProgressService _instance = StudyPlanProgressService._internal();
  factory StudyPlanProgressService() => _instance;
  StudyPlanProgressService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Track completion of a past question quiz
  Future<void> trackPastQuestionCompleted() async {
    await _incrementProgress('past_questions');
  }

  /// Track completion of a textbook chapter
  Future<void> trackTextbookChapterCompleted() async {
    await _incrementProgress('textbook_chapters');
  }

  /// Track usage of an AI tool/session
  Future<void> trackAISessionCompleted() async {
    await _incrementProgress('ai_sessions');
  }

  /// Track completion of a trivia game
  Future<void> trackTriviaGameCompleted() async {
    await _incrementProgress('trivia_games');
  }

  /// Internal method to increment progress counter
  Future<void> _incrementProgress(String progressType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current');

      // Check if study plan exists
      final doc = await docRef.get();
      if (!doc.exists) {
        // No study plan created yet, skip tracking
        return;
      }

      // Increment the specific progress counter
      await docRef.update({
        'progress.$progressType': FieldValue.increment(1),
        'last_activity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - don't disrupt user experience
      debugPrint('Error tracking progress: $e');
    }
  }

  /// Get current progress for analytics/display
  Future<Map<String, int>> getCurrentProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current')
          .get();

      if (!doc.exists) return {};

      final progress = doc.data()?['progress'] as Map<String, dynamic>?;
      if (progress == null) return {};

      return {
        'past_questions': progress['past_questions'] as int? ?? 0,
        'textbook_chapters': progress['textbook_chapters'] as int? ?? 0,
        'ai_sessions': progress['ai_sessions'] as int? ?? 0,
        'trivia_games': progress['trivia_games'] as int? ?? 0,
      };
    } catch (e) {
      print('Error getting progress: $e');
      return {};
    }
  }

  /// Check if user has reached weekly goals (for achievements/notifications)
  Future<Map<String, bool>> checkGoalsReached() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current')
          .get();

      if (!doc.exists) return {};

      final data = doc.data();
      final progress = data?['progress'] as Map<String, dynamic>? ?? {};
      final goals = data?['weekly_goals'] as Map<String, dynamic>? ?? {};

      return {
        'past_questions': (progress['past_questions'] as int? ?? 0) >= (goals['past_questions'] as int? ?? 0),
        'textbook_chapters': (progress['textbook_chapters'] as int? ?? 0) >= (goals['textbook_chapters'] as int? ?? 0),
        'ai_sessions': (progress['ai_sessions'] as int? ?? 0) >= (goals['ai_sessions'] as int? ?? 0),
        'trivia_games': (progress['trivia_games'] as int? ?? 0) >= (goals['trivia_games'] as int? ?? 0),
      };
    } catch (e) {
      print('Error checking goals: $e');
      return {};
    }
  }
}
