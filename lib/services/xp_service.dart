import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class XPService {
  static final XPService _instance = XPService._internal();
  factory XPService() => _instance;
  XPService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // XP Constants
  static const int XP_PER_CORRECT_ANSWER = 5;
  static const int PERFECT_SCORE_BONUS = 20;
  static const int FIRST_TIME_CATEGORY_BONUS = 50;
  static const int MASTER_EXPLORER_BONUS = 100;
  static const int DAILY_LOGIN_BONUS = 10;
  static const int READING_SESSION_XP = 15;
  static const int BOOK_COMPLETION_XP = 50;
  static const int TEXTBOOK_CHAPTER_XP = 10;

  // Trivia categories for Master Explorer tracking
  static const List<String> triviaCategories = [
    'African History',
    'Art and Culture',
    'Geography',
    'Science and Nature',
    'Sports',
    'Music and Entertainment',
    'Food and Cuisine',
    'Technology',
    'Literature',
    'General Knowledge',
    'World History',
    'Politics and Governance',
  ];

  /// Calculate and save XP for a quiz
  Future<int> calculateAndSaveQuizXP({
    required String userId,
    required String quizId,
    required int correctAnswers,
    required int totalQuestions,
    required double percentage,
    required String examType,
    required String subject,
    String? triviaCategory,
  }) async {
    try {
      int xpEarned = 0;

      // Base XP: 5 per correct answer
      xpEarned += correctAnswers * XP_PER_CORRECT_ANSWER;

      // Perfect Score Bonus
      if (percentage == 100.0) {
        xpEarned += PERFECT_SCORE_BONUS;
        print('✨ Perfect Score Bonus: +$PERFECT_SCORE_BONUS XP');
      }

      // First Time Category Bonus
      final isFirstTime = await _isFirstTimeInCategory(
        userId: userId,
        examType: examType,
        subject: subject,
        triviaCategory: triviaCategory,
      );

      if (isFirstTime) {
        xpEarned += FIRST_TIME_CATEGORY_BONUS;
        print('🎉 First Time Bonus: +$FIRST_TIME_CATEGORY_BONUS XP');
        
        // Mark category as completed
        await _markCategoryCompleted(
          userId: userId,
          examType: examType,
          subject: subject,
          triviaCategory: triviaCategory,
        );
      }

      // Check for Master Explorer Badge (all 12 trivia categories)
      if (examType == 'trivia' && triviaCategory != null) {
        final earnedMasterExplorer = await _checkMasterExplorerProgress(userId);
        if (earnedMasterExplorer) {
          xpEarned += MASTER_EXPLORER_BONUS;
          print('👑 Master Explorer Badge Earned: +$MASTER_EXPLORER_BONUS XP');
        }
      }

      // Save XP transaction
      await _saveXPTransaction(
        userId: userId,
        xpAmount: xpEarned,
        source: 'quiz',
        sourceId: quizId,
        details: {
          'examType': examType,
          'subject': subject,
          'triviaCategory': triviaCategory,
          'correctAnswers': correctAnswers,
          'totalQuestions': totalQuestions,
          'percentage': percentage,
          'baseXP': correctAnswers * XP_PER_CORRECT_ANSWER,
          'perfectScoreBonus': percentage == 100.0 ? PERFECT_SCORE_BONUS : 0,
          'firstTimeBonus': isFirstTime ? FIRST_TIME_CATEGORY_BONUS : 0,
        },
      );

      // Update user's total XP
      await _updateUserTotalXP(userId, xpEarned);

      print('💰 Total XP Earned: $xpEarned');
      return xpEarned;
    } catch (e) {
      print('❌ Error calculating quiz XP: $e');
      return 0;
    }
  }

  /// Check if this is the first time user completes a category
  Future<bool> _isFirstTimeInCategory({
    required String userId,
    required String examType,
    required String subject,
    String? triviaCategory,
  }) async {
    try {
      final categoryKey = _getCategoryKey(examType, subject, triviaCategory);
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final completedCategories = (userDoc.data()?['completedCategories'] as List<dynamic>?) ?? [];
      
      return !completedCategories.contains(categoryKey);
    } catch (e) {
      print('Error checking first time category: $e');
      return false;
    }
  }

  /// Mark a category as completed
  Future<void> _markCategoryCompleted({
    required String userId,
    required String examType,
    required String subject,
    String? triviaCategory,
  }) async {
    try {
      final categoryKey = _getCategoryKey(examType, subject, triviaCategory);
      
      await _firestore.collection('users').doc(userId).update({
        'completedCategories': FieldValue.arrayUnion([categoryKey]),
      });
    } catch (e) {
      print('Error marking category completed: $e');
    }
  }

  /// Check if user has completed all 12 trivia categories for Master Explorer
  Future<bool> _checkMasterExplorerProgress(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      // Check if already earned
      final achievements = (data?['achievements'] as List<dynamic>?) ?? [];
      if (achievements.contains('master_explorer')) {
        return false; // Already earned
      }
      
      final completedCategories = (data?['completedCategories'] as List<dynamic>?) ?? [];
      
      // Check if all trivia categories are completed
      int completedTriviaCount = 0;
      for (final category in triviaCategories) {
        final categoryKey = _getCategoryKey('trivia', '', category);
        if (completedCategories.contains(categoryKey)) {
          completedTriviaCount++;
        }
      }
      
      if (completedTriviaCount >= 12) {
        // Award Master Explorer Badge
        await _firestore.collection('users').doc(userId).update({
          'achievements': FieldValue.arrayUnion(['master_explorer']),
          'achievementDates.master_explorer': FieldValue.serverTimestamp(),
        });
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking Master Explorer progress: $e');
      return false;
    }
  }

  /// Save XP transaction for history tracking
  Future<void> _saveXPTransaction({
    required String userId,
    required int xpAmount,
    required String source,
    required String sourceId,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('xp_transactions').add({
        'userId': userId,
        'xpAmount': xpAmount,
        'source': source,
        'sourceId': sourceId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving XP transaction: $e');
    }
  }

  /// Update user's total XP
  Future<void> _updateUserTotalXP(String userId, int xpToAdd) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'totalXP': FieldValue.increment(xpToAdd),
        'lastXPUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user total XP: $e');
    }
  }

  /// Get user's total XP
  Future<int> getUserTotalXP(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['totalXP'] as int?) ?? 0;
    } catch (e) {
      print('Error getting user total XP: $e');
      return 0;
    }
  }

  /// Get user's XP breakdown by category
  Future<Map<String, int>> getUserXPBreakdown(String userId) async {
    try {
      final transactions = await _firestore
          .collection('xp_transactions')
          .where('userId', isEqualTo: userId)
          .get();

      Map<String, int> breakdown = {
        'trivia': 0,
        'bece': 0,
        'wassce': 0,
        'reading': 0,
        'textbooks': 0,
      };

      for (final doc in transactions.docs) {
        final data = doc.data();
        final xpAmount = (data['xpAmount'] as int?) ?? 0;
        final source = data['source'] as String?;
        final details = data['details'] as Map<String, dynamic>?;

        if (source == 'quiz' && details != null) {
          final examType = details['examType'] as String?;
          if (examType == 'trivia') {
            breakdown['trivia'] = (breakdown['trivia'] ?? 0) + xpAmount;
          } else if (examType == 'bece') {
            breakdown['bece'] = (breakdown['bece'] ?? 0) + xpAmount;
          } else if (examType == 'wassce') {
            breakdown['wassce'] = (breakdown['wassce'] ?? 0) + xpAmount;
          }
        } else if (source == 'reading') {
          breakdown['reading'] = (breakdown['reading'] ?? 0) + xpAmount;
        } else if (source == 'textbook') {
          breakdown['textbooks'] = (breakdown['textbooks'] ?? 0) + xpAmount;
        }
      }

      return breakdown;
    } catch (e) {
      print('Error getting XP breakdown: $e');
      return {};
    }
  }

  /// Record daily login and award bonus
  Future<int> recordDailyLogin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastLoginTimestamp = data?['lastLoginDate'] as Timestamp?;
      final lastLoginDate = lastLoginTimestamp?.toDate();
      final today = DateTime.now();
      
      // Check if already logged in today
      if (lastLoginDate != null &&
          lastLoginDate.year == today.year &&
          lastLoginDate.month == today.month &&
          lastLoginDate.day == today.day) {
        return 0; // Already logged in today
      }
      
      // Award daily login bonus
      await _saveXPTransaction(
        userId: userId,
        xpAmount: DAILY_LOGIN_BONUS,
        source: 'daily_login',
        sourceId: 'login_${DateTime.now().millisecondsSinceEpoch}',
        details: {'date': today.toIso8601String()},
      );
      
      await _updateUserTotalXP(userId, DAILY_LOGIN_BONUS);
      
      // Update last login date
      await _firestore.collection('users').doc(userId).update({
        'lastLoginDate': FieldValue.serverTimestamp(),
      });
      
      print('🎁 Daily Login Bonus: +$DAILY_LOGIN_BONUS XP');
      return DAILY_LOGIN_BONUS;
    } catch (e) {
      print('Error recording daily login: $e');
      return 0;
    }
  }

  /// Record reading session XP
  Future<int> recordReadingSession({
    required String userId,
    required String bookId,
    required String bookTitle,
    required int durationMinutes,
  }) async {
    try {
      int xpEarned = READING_SESSION_XP;
      
      await _saveXPTransaction(
        userId: userId,
        xpAmount: xpEarned,
        source: 'reading',
        sourceId: bookId,
        details: {
          'bookTitle': bookTitle,
          'durationMinutes': durationMinutes,
        },
      );
      
      await _updateUserTotalXP(userId, xpEarned);
      
      print('📚 Reading Session XP: +$xpEarned XP');
      return xpEarned;
    } catch (e) {
      print('Error recording reading session: $e');
      return 0;
    }
  }

  /// Record book completion
  Future<int> recordBookCompletion({
    required String userId,
    required String bookId,
    required String bookTitle,
  }) async {
    try {
      int xpEarned = BOOK_COMPLETION_XP;
      
      await _saveXPTransaction(
        userId: userId,
        xpAmount: xpEarned,
        source: 'reading',
        sourceId: bookId,
        details: {
          'bookTitle': bookTitle,
          'completed': true,
        },
      );
      
      await _updateUserTotalXP(userId, xpEarned);
      
      print('🎉 Book Completed: +$xpEarned XP');
      return xpEarned;
    } catch (e) {
      print('Error recording book completion: $e');
      return 0;
    }
  }

  /// Get completed trivia categories count
  Future<int> getCompletedTriviaCategoriesCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final completedCategories = (userDoc.data()?['completedCategories'] as List<dynamic>?) ?? [];
      
      int count = 0;
      for (final category in triviaCategories) {
        final categoryKey = _getCategoryKey('trivia', '', category);
        if (completedCategories.contains(categoryKey)) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      print('Error getting completed trivia categories: $e');
      return 0;
    }
  }

  /// Get category key for tracking
  String _getCategoryKey(String examType, String subject, String? triviaCategory) {
    if (examType == 'trivia' && triviaCategory != null) {
      return 'trivia_$triviaCategory';
    }
    return '${examType}_$subject';
  }

  /// Get tier based on XP
  String getTier(int xp) {
    if (xp >= 10000) return 'Legend';
    if (xp >= 5000) return 'Diamond';
    if (xp >= 2500) return 'Platinum';
    if (xp >= 1000) return 'Gold';
    if (xp >= 500) return 'Silver';
    return 'Bronze';
  }

  /// Get XP needed for next tier
  int getXPToNextTier(int currentXP) {
    if (currentXP >= 10000) return 0; // Max tier
    if (currentXP >= 5000) return 10000 - currentXP;
    if (currentXP >= 2500) return 5000 - currentXP;
    if (currentXP >= 1000) return 2500 - currentXP;
    if (currentXP >= 500) return 1000 - currentXP;
    return 500 - currentXP;
  }

  /// Get next tier name
  String getNextTier(int currentXP) {
    if (currentXP >= 10000) return 'Legend (Max)';
    if (currentXP >= 5000) return 'Legend';
    if (currentXP >= 2500) return 'Diamond';
    if (currentXP >= 1000) return 'Platinum';
    if (currentXP >= 500) return 'Gold';
    return 'Silver';
  }
}
