import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subject_progress_model.dart';

/// Service for calculating various student statistics and metrics.
/// 
/// Handles:
/// - Streak calculations (consecutive study days)
/// - Lifetime study hours computation
/// - Progress aggregation across subjects
/// - Performance level classification
class StatsCalculatorService {
  final FirebaseFirestore? _firestore;

  StatsCalculatorService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  /// Calculates study streak (consecutive days of activity).
  /// 
  /// Returns 0 if:
  /// - No activity dates provided
  /// - Last activity was more than 1 day ago (streak broken)
  /// 
  /// Counts consecutive days working backwards from most recent activity.
  int calculateStreak(List<DateTime> activityDates) {
    if (activityDates.isEmpty) return 0;
    
    // Sort dates in descending order (most recent first)
    final sortedDates = List<DateTime>.from(activityDates)
      ..sort((a, b) => b.compareTo(a));
    
    // Check if user was active today or yesterday
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    final lastActivity = DateTime(
      sortedDates.first.year,
      sortedDates.first.month,
      sortedDates.first.day,
    );
    
    if (lastActivity != today && lastActivity != yesterday) {
      return 0; // Streak broken
    }
    
    // Count consecutive days
    int streak = 1;
    for (int i = 0; i < sortedDates.length - 1; i++) {
      final current = DateTime(
        sortedDates[i].year,
        sortedDates[i].month,
        sortedDates[i].day,
      );
      final next = DateTime(
        sortedDates[i + 1].year,
        sortedDates[i + 1].month,
        sortedDates[i + 1].day,
      );
      
      final difference = current.difference(next).inDays;
      if (difference == 1) {
        streak++;
      } else if (difference > 1) {
        break;
      }
    }
    
    return streak;
  }

  /// Computes lifetime study hours by paginating through all quizzes for a user.
  /// 
  /// Uses pagination to avoid large Firestore reads:
  /// - 500 quizzes per page
  /// - Max 50 pages (25,000 quizzes)
  /// - Assumes 2 minutes per question
  /// 
  /// Returns total study hours, or null on error.
  Future<int?> computeLifetimeStudyHours(String userId) async {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    
    try {
      int totalQuestions = 0;
      final collection = firestore.collection('quizzes');
      Query query = collection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(500);
      
      QuerySnapshot snap = await query.get().timeout(const Duration(seconds: 10));
      
      // Safety limits to prevent infinite loops
      const int maxPages = 50; // Max 25k quizzes (50 * 500)
      int pageCount = 0;
      
      while (pageCount < maxPages) {
        pageCount++;
        if (snap.docs.isEmpty) break;
        
        for (final d in snap.docs) {
          try {
            final data = d.data() as Map<String, dynamic>;
            totalQuestions += (data['totalQuestions'] as int?) ?? 0;
          } catch (_) {
            // Skip malformed documents
          }
        }
        
        if (snap.docs.length < 500) break;
        
        try {
          final last = snap.docs.last;
          snap = await collection
              .where('userId', isEqualTo: userId)
              .orderBy('timestamp', descending: true)
              .startAfterDocument(last)
              .limit(500)
              .get()
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Pagination failed at page $pageCount: $e');
          break; // Exit loop on error
        }
      }
      
      if (pageCount >= maxPages) {
        debugPrint('⚠️ Reached max pagination limit ($maxPages pages)');
      }

      // Assume 2 minutes per question, convert to hours
      final hours = (totalQuestions * 2 / 60).round();
      return hours;
    } catch (e) {
      debugPrint('Error computing lifetimeStudyHours: $e');
      return null;
    }
  }

  /// Calculates overall progress as average across all subjects.
  /// 
  /// Returns 0.0 if no subjects provided.
  double calculateOverallProgress(List<SubjectProgress> subjects) {
    if (subjects.isEmpty) return 0.0;
    final total = subjects.fold<double>(
      0,
      (accumulator, subject) => accumulator + subject.progress
    );
    return total / subjects.length;
  }

  /// Returns a motivational message based on overall progress percentage.
  /// 
  /// Thresholds:
  /// - 80%+: Excellent
  /// - 60-79%: Good
  /// - 40-59%: Making progress
  /// - <40%: Building foundations
  String getOverallPerformanceMessage(List<SubjectProgress> subjects) {
    final overallProgress = calculateOverallProgress(subjects) * 100;
    if (overallProgress >= 80) {
      return 'Excellent progress! Keep up the great work!';
    }
    if (overallProgress >= 60) {
      return 'Good progress. Focus on weaker subjects to excel further.';
    }
    if (overallProgress >= 40) {
      return 'Making progress. Consistent practice will yield results.';
    }
    return 'Building foundations. Regular study will improve your performance.';
  }

  /// Classifies performance level based on progress percentage (0-100).
  /// 
  /// Levels:
  /// - Expert: 90%+
  /// - Advanced: 80-89%
  /// - Proficient: 70-79%
  /// - Developing: 60-69%
  /// - Emerging: 40-59%
  /// - Beginner: <40%
  String getPerformanceLevel(double progressPercent) {
    if (progressPercent >= 90) return 'Expert';
    if (progressPercent >= 80) return 'Advanced';
    if (progressPercent >= 70) return 'Proficient';
    if (progressPercent >= 60) return 'Developing';
    if (progressPercent >= 40) return 'Emerging';
    return 'Beginner';
  }

  /// Calculates accuracy percentage from correct/total questions.
  /// 
  /// Returns 0.0 if total is 0.
  double calculateAccuracy(int correct, int total) {
    if (total == 0) return 0.0;
    return (correct / total) * 100;
  }

  /// Estimates study time in minutes based on number of questions.
  /// 
  /// Assumes 2 minutes per question.
  int estimateStudyTimeMinutes(int questionCount) {
    return questionCount * 2;
  }

  /// Converts study minutes to hours (rounded).
  int convertMinutesToHours(int minutes) {
    return (minutes / 60).round();
  }

  /// Calculates average score from a list of quiz scores.
  /// 
  /// Returns 0.0 if no scores provided.
  double calculateAverageScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    final sum = scores.fold<double>(0, (acc, score) => acc + score);
    return sum / scores.length;
  }

  /// Identifies the weakest subject (lowest progress).
  /// 
  /// Returns null if no subjects provided.
  SubjectProgress? findWeakestSubject(List<SubjectProgress> subjects) {
    if (subjects.isEmpty) return null;
    return subjects.reduce((current, next) => 
      current.progress < next.progress ? current : next
    );
  }

  /// Identifies the strongest subject (highest progress).
  /// 
  /// Returns null if no subjects provided.
  SubjectProgress? findStrongestSubject(List<SubjectProgress> subjects) {
    if (subjects.isEmpty) return null;
    return subjects.reduce((current, next) => 
      current.progress > next.progress ? current : next
    );
  }
}
