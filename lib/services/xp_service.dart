import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'leaderboard_rank_service.dart';
import 'student_data_sync_service.dart';

class XPService {
  static final XPService _instance = XPService._internal();
  factory XPService() => _instance;
  XPService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LeaderboardRankService _rankService = LeaderboardRankService();
  final StudentDataSyncService _syncService = StudentDataSyncService();

  // XP Constants - Quiz & Learning
  static const int XP_PER_CORRECT_ANSWER = 5;
  static const int PERFECT_SCORE_BONUS = 20;
  static const int FIRST_TIME_CATEGORY_BONUS = 50;
  static const int MASTER_EXPLORER_BONUS = 100;
  
  // XP Constants - Daily Activities
  static const int DAILY_LOGIN_BONUS = 50;
  static const int READING_SESSION_XP = 15;
  static const int BOOK_COMPLETION_XP = 50;
  static const int TEXTBOOK_CHAPTER_XP = 10;
  
  // XP Constants - Social & Contribution
  static const int UPLOAD_NOTES_XP = 150;
  static const int NOTE_UPVOTE_XP = 10;
  static const int NOTE_DOWNLOAD_XP = 5;
  
  // XP Constants - Streaks & Milestones
  static const int SEVEN_DAY_STREAK_BONUS = 300;
  static const int THIRTY_DAY_STREAK_BONUS = 1500;
  static const int PERFECT_ATTENDANCE_BONUS = 2000;
  
  // XP Constants - Advanced
  static const int AI_REVISION_PLAN_XP = 500;
  static const int SUBJECT_MODULE_COMPLETION_XP = 1500;
  static const int MONTHLY_CONTEST_WINNER_XP = 5000;

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
        debugPrint('✨ Perfect Score Bonus: +$PERFECT_SCORE_BONUS XP');
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
        debugPrint('🎉 First Time Bonus: +$FIRST_TIME_CATEGORY_BONUS XP');
        
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
          debugPrint('👑 Master Explorer Badge Earned: +$MASTER_EXPLORER_BONUS XP');
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

      debugPrint('💰 Total XP Earned: $xpEarned');
      return xpEarned;
    } catch (e) {
      debugPrint('❌ Error calculating quiz XP: $e');
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
      debugPrint('Error checking first time category: $e');
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
      debugPrint('Error marking category completed: $e');
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
      debugPrint('Error checking Master Explorer progress: $e');
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
      debugPrint('Error saving XP transaction: $e');
    }
  }

  /// Update user's total XP and check for rank up
  Future<Map<String, dynamic>> _updateUserTotalXP(String userId, int xpToAdd) async {
    try {
      // Get current XP
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentXP = (userDoc.data()?['totalXP'] as int?) ?? 0;
      final newXP = currentXP + xpToAdd;

      // Get old and new ranks
      final oldRank = await _rankService.getUserRank(currentXP);
      final newRank = await _rankService.getUserRank(newXP);

      // Update XP
      await _firestore.collection('users').doc(userId).update({
        'totalXP': FieldValue.increment(xpToAdd),
        'lastXPUpdate': FieldValue.serverTimestamp(),
      });

      // Check for rank up
      bool rankedUp = false;
      if (oldRank != null && newRank != null && oldRank.rank < newRank.rank) {
        await _handleRankUp(userId, oldRank, newRank);
        rankedUp = true;
      }

      // Sync student data to studentSummaries for teacher dashboard
      await _syncService.syncStudentData(userId);

      return {
        'rankedUp': rankedUp,
        'oldRank': oldRank,
        'newRank': newRank,
        'newXP': newXP,
      };
    } catch (e) {
      debugPrint('Error updating user total XP: $e');
      return {
        'rankedUp': false,
        'oldRank': null,
        'newRank': null,
        'newXP': 0,
      };
    }
  }

  /// Handle rank up event
  Future<void> _handleRankUp(
    String userId,
    LeaderboardRank oldRank,
    LeaderboardRank newRank,
  ) async {
    try {
      // Log rank achievement
      await _firestore.collection('rankAchievements').add({
        'userId': userId,
        'oldRank': oldRank.rank,
        'oldRankName': oldRank.name,
        'newRank': newRank.rank,
        'newRankName': newRank.name,
        'tier': newRank.tier,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user's current rank
      await _firestore.collection('users').doc(userId).update({
        'currentRank': newRank.rank,
        'currentRankName': newRank.name,
        'currentTier': newRank.tier,
        'rankImageUrl': newRank.imageUrl,
      });

      debugPrint('🎉 RANK UP! ${oldRank.name} → ${newRank.name}');
    } catch (e) {
      debugPrint('Error handling rank up: $e');
    }
  }

  /// Get user's current rank
  Future<LeaderboardRank?> getUserRank(String userId) async {
    try {
      final xp = await getUserTotalXP(userId);
      return await _rankService.getUserRank(xp);
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return null;
    }
  }

  /// Get user's next rank
  Future<LeaderboardRank?> getNextRank(String userId) async {
    try {
      final xp = await getUserTotalXP(userId);
      return await _rankService.getNextRank(xp);
    } catch (e) {
      debugPrint('Error getting next rank: $e');
      return null;
    }
  }

  /// Get user's total XP
  Future<int> getUserTotalXP(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['totalXP'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting user total XP: $e');
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
      debugPrint('Error getting XP breakdown: $e');
      return {};
    }
  }

  /// Record daily login and award bonus with streak tracking
  Future<Map<String, dynamic>> recordDailyLogin(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      
      final lastLoginTimestamp = data?['lastLoginDate'] as Timestamp?;
      final lastLoginDate = lastLoginTimestamp?.toDate();
      final currentStreak = (data?['currentStreak'] as int?) ?? 0;
      final today = DateTime.now();
      
      // Check if already logged in today
      if (lastLoginDate != null &&
          lastLoginDate.year == today.year &&
          lastLoginDate.month == today.month &&
          lastLoginDate.day == today.day) {
        return {
          'xpEarned': 0,
          'streakBonus': 0,
          'currentStreak': currentStreak,
          'message': 'Already logged in today'
        }; // Already logged in today
      }
      
      int totalXP = DAILY_LOGIN_BONUS;
      int streakBonus = 0;
      int newStreak = 1;
      
      // Check if streak continues (logged in yesterday)
      if (lastLoginDate != null) {
        final yesterday = today.subtract(const Duration(days: 1));
        if (lastLoginDate.year == yesterday.year &&
            lastLoginDate.month == yesterday.month &&
            lastLoginDate.day == yesterday.day) {
          newStreak = currentStreak + 1;
        }
      }
      
      // Check for streak milestones
      if (newStreak == 7) {
        streakBonus = SEVEN_DAY_STREAK_BONUS;
        totalXP += streakBonus;
        debugPrint('🔥 7-Day Streak Bonus: +$streakBonus XP');
      } else if (newStreak == 30) {
        streakBonus = THIRTY_DAY_STREAK_BONUS;
        totalXP += streakBonus;
        debugPrint('🔥🔥 30-Day Streak Bonus: +$streakBonus XP');
      } else if (newStreak % 7 == 0 && newStreak > 0) {
        // Weekly milestone bonus
        streakBonus = SEVEN_DAY_STREAK_BONUS;
        totalXP += streakBonus;
        debugPrint('🔥 Weekly Streak Milestone: +$streakBonus XP');
      }
      
      // Award daily login bonus
      await _saveXPTransaction(
        userId: userId,
        xpAmount: totalXP,
        source: 'daily_login',
        sourceId: 'login_${DateTime.now().millisecondsSinceEpoch}',
        details: {
          'date': today.toIso8601String(),
          'streak': newStreak,
          'streakBonus': streakBonus,
        },
      );
      
      await _updateUserTotalXP(userId, totalXP);
      
      // Update last login date and streak
      await _firestore.collection('users').doc(userId).update({
        'lastLoginDate': FieldValue.serverTimestamp(),
        'currentStreak': newStreak,
        'longestStreak': newStreak > (data?['longestStreak'] as int? ?? 0) 
            ? newStreak 
            : data?['longestStreak'],
      });
      
      debugPrint('🎁 Daily Login: +$DAILY_LOGIN_BONUS XP (Streak: $newStreak days)');
      return {
        'xpEarned': totalXP,
        'streakBonus': streakBonus,
        'currentStreak': newStreak,
        'message': streakBonus > 0 
            ? 'Streak milestone reached!' 
            : 'Keep it up! Day $newStreak'
      };
    } catch (e) {
      debugPrint('Error recording daily login: $e');
      return {
        'xpEarned': 0,
        'streakBonus': 0,
        'currentStreak': 0,
        'message': 'Error recording login'
      };
    }
  }
  
  /// Record note upload
  Future<int> recordNoteUpload({
    required String userId,
    required String noteId,
    required String noteTitle,
    required String subject,
  }) async {
    try {
      await _saveXPTransaction(
        userId: userId,
        xpAmount: UPLOAD_NOTES_XP,
        source: 'note_upload',
        sourceId: noteId,
        details: {
          'noteTitle': noteTitle,
          'subject': subject,
        },
      );
      
      await _updateUserTotalXP(userId, UPLOAD_NOTES_XP);
      
      debugPrint('📝 Note Uploaded: +$UPLOAD_NOTES_XP XP');
      return UPLOAD_NOTES_XP;
    } catch (e) {
      debugPrint('Error recording note upload: $e');
      return 0;
    }
  }
  
  /// Record note engagement (upvote/download)
  Future<int> recordNoteEngagement({
    required String noteOwnerId,
    required String noteId,
    required String engagementType, // 'upvote' or 'download'
  }) async {
    try {
      final xp = engagementType == 'upvote' ? NOTE_UPVOTE_XP : NOTE_DOWNLOAD_XP;
      
      await _saveXPTransaction(
        userId: noteOwnerId,
        xpAmount: xp,
        source: 'note_engagement',
        sourceId: noteId,
        details: {
          'engagementType': engagementType,
        },
      );
      
      await _updateUserTotalXP(noteOwnerId, xp);
      
      debugPrint('👍 Note $engagementType: +$xp XP');
      return xp;
    } catch (e) {
      debugPrint('Error recording note engagement: $e');
      return 0;
    }
  }
  
  /// Record AI revision plan completion
  Future<int> recordAIRevisionPlan({
    required String userId,
    required String planId,
    required String subject,
  }) async {
    try {
      await _saveXPTransaction(
        userId: userId,
        xpAmount: AI_REVISION_PLAN_XP,
        source: 'ai_revision_plan',
        sourceId: planId,
        details: {
          'subject': subject,
        },
      );
      
      await _updateUserTotalXP(userId, AI_REVISION_PLAN_XP);
      
      debugPrint('🤖 AI Revision Plan Completed: +$AI_REVISION_PLAN_XP XP');
      return AI_REVISION_PLAN_XP;
    } catch (e) {
      debugPrint('Error recording AI revision plan: $e');
      return 0;
    }
  }
  
  /// Record subject module completion
  Future<int> recordSubjectModuleCompletion({
    required String userId,
    required String moduleId,
    required String subject,
  }) async {
    try {
      await _saveXPTransaction(
        userId: userId,
        xpAmount: SUBJECT_MODULE_COMPLETION_XP,
        source: 'module_completion',
        sourceId: moduleId,
        details: {
          'subject': subject,
        },
      );
      
      await _updateUserTotalXP(userId, SUBJECT_MODULE_COMPLETION_XP);
      
      debugPrint('🎓 Subject Module Completed: +$SUBJECT_MODULE_COMPLETION_XP XP');
      return SUBJECT_MODULE_COMPLETION_XP;
    } catch (e) {
      debugPrint('Error recording module completion: $e');
      return 0;
    }
  }
  
  /// Award monthly contest winner
  Future<int> recordMonthlyContestWin({
    required String userId,
    required String contestId,
    required String contestName,
  }) async {
    try {
      await _saveXPTransaction(
        userId: userId,
        xpAmount: MONTHLY_CONTEST_WINNER_XP,
        source: 'contest_win',
        sourceId: contestId,
        details: {
          'contestName': contestName,
        },
      );
      
      await _updateUserTotalXP(userId, MONTHLY_CONTEST_WINNER_XP);
      
      debugPrint('🏆 Monthly Contest Won: +$MONTHLY_CONTEST_WINNER_XP XP');
      return MONTHLY_CONTEST_WINNER_XP;
    } catch (e) {
      debugPrint('Error recording contest win: $e');
      return 0;
    }
  }
  
  /// Get current streak
  Future<int> getCurrentStreak(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['currentStreak'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error getting current streak: $e');
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
      
      debugPrint('📚 Reading Session XP: +$xpEarned XP');
      return xpEarned;
    } catch (e) {
      debugPrint('Error recording reading session: $e');
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
      
      debugPrint('🎉 Book Completed: +$xpEarned XP');
      return xpEarned;
    } catch (e) {
      debugPrint('Error recording book completion: $e');
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
      debugPrint('Error getting completed trivia categories: $e');
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
