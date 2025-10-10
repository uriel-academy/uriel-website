import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_model.dart';

class QuizService {
  static const String _quizHistoryKey = 'quiz_history';
  static const String _quizStatsKey = 'quiz_stats';
  static const String _currentSessionKey = 'current_quiz_session';

  // Save completed quiz
  Future<void> saveCompletedQuiz(Quiz quiz) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing quiz history
      final String? historyJson = prefs.getString(_quizHistoryKey);
      List<Quiz> quizHistory = [];
      
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        quizHistory = historyList.map((item) => Quiz.fromJson(item)).toList();
      }
      
      // Add new quiz to history
      quizHistory.insert(0, quiz); // Add to beginning for most recent first
      
      // Keep only last 50 quizzes to prevent storage bloat
      if (quizHistory.length > 50) {
        quizHistory = quizHistory.take(50).toList();
      }
      
      // Save updated history
      final String updatedJson = json.encode(quizHistory.map((q) => q.toJson()).toList());
      await prefs.setString(_quizHistoryKey, updatedJson);
      
      // Update stats
      await _updateQuizStats(quiz);
      
    } catch (e) {
      print('Error saving quiz: $e');
    }
  }

  // Get quiz history
  Future<List<Quiz>> getQuizHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_quizHistoryKey);
      
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        return historyList.map((item) => Quiz.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error loading quiz history: $e');
      return [];
    }
  }

  // Get quiz statistics
  Future<QuizStats> getQuizStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? statsJson = prefs.getString(_quizStatsKey);
      
      if (statsJson != null) {
        return QuizStats.fromJson(json.decode(statsJson));
      }
      
      // Return default stats if none exist
      return QuizStats(
        totalQuizzesTaken: 0,
        averageScore: 0.0,
        bestScore: 0,
        favoriteSubject: 'Not Available',
        totalTimeSpent: const Duration(),
        recentQuizzes: [],
      );
    } catch (e) {
      print('Error loading quiz stats: $e');
      return QuizStats(
        totalQuizzesTaken: 0,
        averageScore: 0.0,
        bestScore: 0,
        favoriteSubject: 'Not Available',
        totalTimeSpent: const Duration(),
        recentQuizzes: [],
      );
    }
  }

  // Update quiz statistics
  Future<void> _updateQuizStats(Quiz quiz) async {
    try {
      final quizHistory = await getQuizHistory();
      
      // Calculate new stats
      final totalQuizzes = quizHistory.length;
      final averageScore = quizHistory.isNotEmpty 
          ? quizHistory.map((q) => q.percentage).reduce((a, b) => a + b) / totalQuizzes
          : 0.0;
      final bestScore = quizHistory.isNotEmpty 
          ? quizHistory.map((q) => q.percentage).reduce((a, b) => a > b ? a : b).round()
          : 0;
      
      // Calculate favorite subject
      final Map<String, int> subjectCounts = {};
      for (final q in quizHistory) {
        subjectCounts[q.subject] = (subjectCounts[q.subject] ?? 0) + 1;
      }
      final favoriteSubject = subjectCounts.isNotEmpty 
          ? subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'Not Available';
      
      // Calculate total time spent
      final totalTime = quizHistory.fold<Duration>(
        const Duration(),
        (total, quiz) => total + quiz.duration,
      );
      
      // Create updated stats
      final updatedStats = QuizStats(
        totalQuizzesTaken: totalQuizzes,
        averageScore: averageScore,
        bestScore: bestScore,
        favoriteSubject: favoriteSubject,
        totalTimeSpent: totalTime,
        recentQuizzes: quizHistory.take(5).toList(),
      );
      
      // Save updated stats
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizStatsKey, json.encode(updatedStats.toJson()));
      
    } catch (e) {
      print('Error updating quiz stats: $e');
    }
  }

  // Save current quiz session (for pause/resume functionality)
  Future<void> saveQuizSession(QuizSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentSessionKey, json.encode(session.toJson()));
    } catch (e) {
      print('Error saving quiz session: $e');
    }
  }

  // Load current quiz session
  Future<QuizSession?> loadQuizSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? sessionJson = prefs.getString(_currentSessionKey);
      
      if (sessionJson != null) {
        return QuizSession.fromJson(json.decode(sessionJson));
      }
      
      return null;
    } catch (e) {
      print('Error loading quiz session: $e');
      return null;
    }
  }

  // Clear current quiz session
  Future<void> clearQuizSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentSessionKey);
    } catch (e) {
      print('Error clearing quiz session: $e');
    }
  }

  // Get quizzes by subject
  Future<List<Quiz>> getQuizzesBySubject(String subject) async {
    final history = await getQuizHistory();
    return history.where((quiz) => quiz.subject == subject).toList();
  }

  // Get recent performance for a subject
  Future<List<double>> getRecentPerformance(String subject, {int count = 10}) async {
    final quizzes = await getQuizzesBySubject(subject);
    return quizzes.take(count).map((quiz) => quiz.percentage).toList();
  }

  // Calculate improvement trend
  Future<double> getImprovementTrend(String subject) async {
    final performance = await getRecentPerformance(subject, count: 5);
    
    if (performance.length < 2) return 0.0;
    
    // Simple trend calculation: difference between average of first half and second half
    final midPoint = performance.length ~/ 2;
    final recentAvg = performance.take(midPoint).reduce((a, b) => a + b) / midPoint;
    final olderAvg = performance.skip(midPoint).reduce((a, b) => a + b) / (performance.length - midPoint);
    
    return recentAvg - olderAvg;
  }

  // Export quiz history to JSON
  Future<String> exportQuizHistory() async {
    final history = await getQuizHistory();
    final stats = await getQuizStats();
    
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'statistics': stats.toJson(),
      'quizHistory': history.map((q) => q.toJson()).toList(),
    };
    
    return json.encode(exportData);
  }

  // Clear all quiz data (for reset functionality)
  Future<void> clearAllQuizData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_quizHistoryKey);
      await prefs.remove(_quizStatsKey);
      await prefs.remove(_currentSessionKey);
    } catch (e) {
      print('Error clearing quiz data: $e');
    }
  }

  // Get leaderboard data (if implementing multiplayer features)
  Future<List<Map<String, dynamic>>> getLeaderboard(String subject) async {
    // This would integrate with Firebase/backend for multiplayer features
    // For now, return local stats formatted as leaderboard entry
    final stats = await getQuizStats();
    
    return [
      {
        'rank': 1,
        'name': 'You',
        'averageScore': stats.averageScore,
        'totalQuizzes': stats.totalQuizzesTaken,
        'bestScore': stats.bestScore,
      }
    ];
  }

  // Calculate difficulty adjustment recommendations
  Future<Map<String, dynamic>> getDifficultyRecommendations(String subject) async {
    final recentQuizzes = await getQuizzesBySubject(subject);
    
    if (recentQuizzes.isEmpty) {
      return {
        'recommendedDifficulty': 'medium',
        'reason': 'No previous attempts',
        'confidence': 0.0,
      };
    }
    
    final recentPerformance = recentQuizzes.take(3).map((q) => q.percentage).toList();
    final avgPerformance = recentPerformance.reduce((a, b) => a + b) / recentPerformance.length;
    
    String recommendedDifficulty;
    String reason;
    double confidence = recentPerformance.length / 3.0; // Confidence based on sample size
    
    if (avgPerformance >= 85) {
      recommendedDifficulty = 'hard';
      reason = 'Excellent performance - ready for challenge';
    } else if (avgPerformance >= 70) {
      recommendedDifficulty = 'medium';
      reason = 'Good performance - maintain current level';
    } else {
      recommendedDifficulty = 'easy';
      reason = 'Focus on fundamentals first';
    }
    
    return {
      'recommendedDifficulty': recommendedDifficulty,
      'reason': reason,
      'confidence': confidence,
      'averagePerformance': avgPerformance,
    };
  }
}