import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_styles.dart';
import '../services/connection_service.dart';
import '../services/auth_service.dart';
import '../services/xp_service.dart';
import '../services/leaderboard_rank_service.dart';
import '../widgets/rank_badge_widget.dart';
import 'redesigned_all_ranks_page.dart';
import 'question_collections_page.dart';
import 'textbooks_page.dart';
import 'feedback_page.dart';
import 'trivia_categories_page.dart';
import 'student_profile_page.dart';
import 'redesigned_leaderboard_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _selectedIndex = 0;
  bool _showingProfile = false;
  
  // User progress data - Live from Firestore
  String userName = "";
  String userClass = "JHS Form 3 Student";
  String? userPhotoUrl;
  String? userPresetAvatar;
  double overallProgress = 0.0; // Calculated from quiz results
  int currentStreak = 0; // Days of consecutive activity
  int weeklyStudyHours = 0; // Calculated from session time
  int questionsAnswered = 0; // Total questions from quizzes
  int beceCountdownDays = 0; // Live countdown to BECE 2026
  Stream<DocumentSnapshot>? _userStream;
  
  // Past Questions tracking
  int pastQuestionsAnswered = 0;
  double pastQuestionsProgress = 0.0;
  
  // Trivia tracking
  int triviaQuestionsAnswered = 0;
  double triviaProgress = 0.0;
  int triviaCorrect = 0;
  
  // Rank tracking
  int userXP = 0;
  LeaderboardRank? currentRank;
  LeaderboardRank? nextRank;
  
  // Subject progress data - Live from quiz performance
  List<SubjectProgress> _subjectProgress = [];
  
  // Recent activity data
  // ignore: unused_field
  List<Map<String, dynamic>> _recentActivity = [];

  // Dynamic activity items for display
  List<Map<String, dynamic>> _activityItems = [];

  // Dynamic achievements for display
  List<Map<String, dynamic>> _userAchievements = [];

  // Dynamic study recommendations
  List<String> _studyRecommendations = [];

  // ML-powered personalization data
  Map<String, dynamic> _userBehaviorProfile = {};
  List<String> _personalizedContent = [];

  List<Map<String, dynamic>> _upcomingItems = [];

  // Performance trend tracking
  double _previousWeekScore = 0.0;
  int _previousWeekQuestions = 0;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 5, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    _calculateBeceCountdown();
    _loadUserData();
    _loadUserStats();
    _loadUserRank();
    _recordDailyActivity();
    _setupUserStream();
  }
  
  void _loadUserRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final xpService = XPService();
      final rankService = LeaderboardRankService();
      
      // Get user XP
      final xp = await xpService.getUserTotalXP(user.uid);
      
      // Get current and next rank
      final current = await rankService.getUserRank(xp);
      final next = await rankService.getNextRank(xp);
      
      setState(() {
        userXP = xp;
        currentRank = current;
        nextRank = next;
      });
      
      debugPrint('👑 User Rank: ${current?.name} (Rank #${current?.rank}) - XP: $xp');
      debugPrint('🖼️ Rank Image URL: ${current?.imageUrl}');
      if (current?.imageUrl.isEmpty ?? true) {
        debugPrint('⚠️ WARNING: Rank image URL is empty!');
      }
    } catch (e) {
      debugPrint('❌ Error loading user rank: $e');
    }
  }
  
  void _setupUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
      
      // Listen to changes and update state
      _userStream!.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          debugPrint('🔄 User data updated from Firestore:');
          debugPrint('  presetAvatar: ${data['presetAvatar']}');
          debugPrint('  profileImageUrl: ${data['profileImageUrl']}');
          setState(() {
            userName = data['firstName'] ?? user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
            userClass = data['class'] ?? 'JHS Form 3';
            userPhotoUrl = data['profileImageUrl'] ?? user.photoURL;
            userPresetAvatar = data['presetAvatar'];
          });
        }
      });
    }
  }
  
  ImageProvider? _getAvatarImage() {
    if (userPresetAvatar != null) {
      return AssetImage(userPresetAvatar!);
    } else if (userPhotoUrl != null) {
      return NetworkImage(userPhotoUrl!);
    }
    return null;
  }

  void _recordDailyActivity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Import will be added
        // final streakResult = await StreakService().recordDailyActivity(user.uid);
        // Show streak notification if earned XP
        // if (streakResult['xpEarned'] > 0) {
        //   _showStreakNotification(streakResult);
        // }
      } catch (e) {
        debugPrint('Error recording daily activity: $e');
      }
    }
  }
  
  void _calculateBeceCountdown() {
    // BECE 2026: May 4 - May 11, 2026
    final beceStartDate = DateTime(2026, 5, 4);
    final now = DateTime.now();
    final difference = beceStartDate.difference(now);
    
    setState(() {
      beceCountdownDays = difference.inDays > 0 ? difference.inDays : 0;
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Set a timeout for the Firestore operation
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );
        
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            userName = data['firstName'] ?? user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
            userClass = data['class'] ?? 'JHS Form 3';
            userPhotoUrl = data['profileImageUrl'] ?? user.photoURL;
            userPresetAvatar = data['presetAvatar'];
          });
        } else {
          setState(() {
            userName = user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
            userClass = 'JHS Form 3';
          });
        }
      } catch (e) {
        // Handle offline or connection errors gracefully
        setState(() {
          userName = user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
        });
        
        // Only log the error, don't show it to the user
        debugPrint('Unable to load user data (offline or connection issue): $e');
      }
    } else {
      // Set default name when no user is logged in
      setState(() {
        userName = 'Student';
      });
    }
  }
  
  Future<void> _loadUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Load quiz results for the user
      final quizSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (quizSnapshot.docs.isEmpty) {
        // No quiz data yet - show 0%
        setState(() {
          questionsAnswered = 0;
          overallProgress = 0.0;
          currentStreak = 0;
          _subjectProgress = [];
          _recentActivity = [];
        });
        return;
      }
      
      // Calculate stats from quiz data
      int totalQuestions = 0;
      int totalCorrect = 0;
      int pastQuestionsTotal = 0;
      int pastQuestionsCorrect = 0;
      int triviaTotal = 0;
      int triviaCorrect = 0;
      Map<String, List<double>> subjectScores = {};
      List<DateTime> activityDates = [];
      List<Map<String, dynamic>> recentQuizzes = [];
      
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        int questions = (data['totalQuestions'] as int?) ?? 0;
        int correct = (data['correctAnswers'] as int?) ?? 0;
        
        totalQuestions += questions;
        totalCorrect += correct;
        
        // Track subject progress
        String subject = data['subject'] ?? 'Unknown';
        String quizType = data['quizType'] ?? '';
        double score = (data['percentage'] as num?)?.toDouble() ?? 0.0;
        
        // Separate tracking for past questions (BECE questions)
        if (quizType.toLowerCase().contains('bece') || 
            subject.toLowerCase().contains('bece') ||
            quizType.toLowerCase().contains('past')) {
          pastQuestionsTotal += questions;
          pastQuestionsCorrect += correct;
        }
        
        // Separate tracking for trivia
        if (quizType.toLowerCase().contains('trivia') || 
            subject.toLowerCase().contains('trivia')) {
          triviaTotal += questions;
          triviaCorrect += correct;
        }
        
        if (!subjectScores.containsKey(subject)) {
          subjectScores[subject] = [];
        }
        subjectScores[subject]!.add(score);
        
        // Track activity dates for streak
        if (data['timestamp'] != null) {
          try {
            DateTime date;
            if (data['timestamp'] is Timestamp) {
              date = (data['timestamp'] as Timestamp).toDate();
            } else {
              date = DateTime.parse(data['timestamp'].toString());
            }
            activityDates.add(date);
          } catch (e) {
            debugPrint('Error parsing timestamp: $e');
          }
        }
        
        // Recent activity
        if (recentQuizzes.length < 5) {
          recentQuizzes.add({
            'subject': subject,
            'score': score,
            'date': data['timestamp'],
            'questions': data['totalQuestions'] ?? 0,
          });
        }
      }
      
      // Calculate overall progress
      double avgProgress = totalQuestions > 0 
          ? (totalCorrect / totalQuestions * 100) 
          : 0.0;
      
      // Calculate past questions progress
      double pastQProgress = pastQuestionsTotal > 0 
          ? (pastQuestionsCorrect / pastQuestionsTotal * 100) 
          : 0.0;
      
      // Calculate trivia progress
      double triviaAvg = triviaTotal > 0 
          ? (triviaCorrect / triviaTotal * 100) 
          : 0.0;
      
      // Calculate streak
      int streak = _calculateStreak(activityDates);
      
      // Calculate study hours (estimate: 2 minutes per question, filtered for this week)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
      
      int weeklyQuestions = 0;
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        if (data['timestamp'] != null) {
          try {
            DateTime date;
            if (data['timestamp'] is Timestamp) {
              date = (data['timestamp'] as Timestamp).toDate();
            } else {
              date = DateTime.parse(data['timestamp'].toString());
            }
            if (date.isAfter(weekStartDate)) {
              weeklyQuestions += (data['totalQuestions'] as int?) ?? 0;
            }
          } catch (e) {
            debugPrint('Error parsing timestamp for study hours: $e');
          }
        }
      }
      
      int studyHours = (weeklyQuestions * 2 / 60).round(); // 2 minutes per question
      
      // Build subject progress list
      List<SubjectProgress> subjects = [];
      final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
      int colorIndex = 0;
      
      subjectScores.forEach((subject, scores) {
        double avgScore = scores.reduce((a, b) => a + b) / scores.length;
        subjects.add(SubjectProgress(
          subject, 
          avgScore, 
          colors[colorIndex % colors.length]
        ));
        colorIndex++;
      });
      
      setState(() {
        questionsAnswered = totalQuestions;
        overallProgress = avgProgress;
        currentStreak = streak;
        weeklyStudyHours = studyHours;
        _subjectProgress = subjects;
        _recentActivity = recentQuizzes;
        
        // Past questions metrics
        pastQuestionsAnswered = pastQuestionsTotal;
        pastQuestionsProgress = pastQProgress;
        
        // Trivia metrics
        triviaQuestionsAnswered = triviaTotal;
        triviaProgress = triviaAvg;
        triviaCorrect = triviaCorrect;
      });
      
      // Generate dynamic activity items
      _generateActivityItems();
      
      // Detect user achievements
      _detectAchievements();
      
      // Generate intelligent study recommendations
      _generateStudyRecommendations();
      
      // Analyze user behavior for ML-powered personalization
      _analyzeUserBehaviorProfile();
      
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      // Keep default values (0) on error
    }
  }
  
  int _calculateStreak(List<DateTime> activityDates) {
    if (activityDates.isEmpty) return 0;
    
    // Sort dates
    activityDates.sort((a, b) => b.compareTo(a));
    
    // Check if user was active today or yesterday
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    final lastActivity = DateTime(
      activityDates.first.year,
      activityDates.first.month,
      activityDates.first.day,
    );
    
    if (lastActivity != today && lastActivity != yesterday) {
      return 0; // Streak broken
    }
    
    // Count consecutive days
    int streak = 1;
    for (int i = 0; i < activityDates.length - 1; i++) {
      final current = DateTime(
        activityDates[i].year,
        activityDates[i].month,
        activityDates[i].day,
      );
      final next = DateTime(
        activityDates[i + 1].year,
        activityDates[i + 1].month,
        activityDates[i + 1].day,
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
  
  void _generateActivityItems() {
    if (_recentActivity.isEmpty) {
      // Generate intelligent default activities based on user profile
      _generateSmartDefaultActivities();
      return;
    }

    _activityItems = [];
    final now = DateTime.now();
    final userProfile = _userBehaviorProfile;

    // Sort activities by recency and relevance
    final sortedActivities = List<Map<String, dynamic>>.from(_recentActivity)
      ..sort((a, b) {
        final aDate = _parseActivityDate(a['date']);
        final bDate = _parseActivityDate(b['date']);
        final aRelevance = _calculateActivityRelevance(a, userProfile);
        final bRelevance = _calculateActivityRelevance(b, userProfile);
        // Sort by relevance first, then by recency
        if (aRelevance != bRelevance) {
          return bRelevance.compareTo(aRelevance);
        }
        return bDate.compareTo(aDate);
      });

    for (var activity in sortedActivities) {
      final subject = activity['subject'] ?? 'General';
      final score = activity['score'] ?? 0.0;
      final questions = activity['questions'] ?? 0;
      final timestamp = activity['date'];

      final activityDate = _parseActivityDate(timestamp);
      final timeAgo = _getTimeAgo(activityDate);
      final isHighScore = score >= 80.0;
      final isPerfect = score >= 95.0;
      final isRecent = now.difference(activityDate).inHours < 24;

      // Enhanced activity type determination with ML insights
      final activityType = _classifyActivityType(activity, userProfile);
      final smartMessage = _generateSmartActivityMessage(activity, activityType, userProfile);

      // Dynamic color and icon based on performance and type
      final displayConfig = _getActivityDisplayConfig(activityType, score, isRecent);

      _activityItems.add({
        'title': smartMessage['title'],
        'time': timeAgo,
        'icon': displayConfig['icon'],
        'color': displayConfig['color'],
        'detail': smartMessage['detail'],
        'relevance': _calculateActivityRelevance(activity, userProfile),
        'type': activityType,
      });

      if (_activityItems.length >= 6) break; // Increased limit for more activity
    }

    // Add contextual motivational messages
    _addContextualMotivationalActivities();

    // Ensure we have at least 3 activities
    while (_activityItems.length < 3) {
      _addFallbackActivity();
    }

    // Sort final list by relevance
    _activityItems.sort((a, b) => (b['relevance'] as int).compareTo(a['relevance'] as int));
  }

  void _generateSmartDefaultActivities() {
    final profile = _userBehaviorProfile;
    final learningStyle = profile['learningStyle'] as String? ?? 'explorer';
    final engagementLevel = profile['engagementLevel'] as String? ?? 'needs_encouragement';

    _activityItems = [];

    // Generate activities based on user profile
    switch (learningStyle) {
      case 'quick_learner':
        _activityItems.add({
          'title': '🚀 Ready for Advanced Challenges?',
          'time': 'Now',
          'icon': Icons.rocket_launch,
          'color': const Color(0xFFD62828),
          'detail': 'Take on harder questions to accelerate your progress',
          'relevance': 10,
        });
        break;
      case 'consistent_builder':
        _activityItems.add({
          'title': '📈 Build Your Knowledge Foundation',
          'time': 'Today',
          'icon': Icons.foundation,
          'color': const Color(0xFF4CAF50),
          'detail': 'Consistent practice leads to lasting mastery',
          'relevance': 10,
        });
        break;
      case 'challenge_seeker':
        _activityItems.add({
          'title': '🎯 Challenge Yourself Today',
          'time': 'Now',
          'icon': Icons.sports_score,
          'color': const Color(0xFFFF9800),
          'detail': 'Push your limits with difficult questions',
          'relevance': 10,
        });
        break;
      default:
        _activityItems.add({
          'title': '🌟 Start Your Learning Journey',
          'time': 'Now',
          'icon': Icons.explore,
          'color': const Color(0xFF2196F3),
          'detail': 'Discover what subjects excite you most',
          'relevance': 10,
        });
    }

    // Add engagement-based activities
    if (engagementLevel == 'highly_engaged') {
      _activityItems.add({
        'title': '🔥 Keep the Momentum Going!',
        'time': 'Today',
        'icon': Icons.local_fire_department,
        'color': const Color(0xFFFF5722),
        'detail': 'You\'re on fire! Maintain your excellent streak',
        'relevance': 9,
      });
    } else {
      _activityItems.add({
        'title': '💪 Every Journey Begins with a Step',
        'time': 'Today',
        'icon': Icons.directions_walk,
        'color': const Color(0xFF4CAF50),
        'detail': 'Take your first quiz and start building momentum',
        'relevance': 9,
      });
    }

    // Add subject-specific suggestions
    final preferredSubjects = profile['preferredSubjects'] as List<String>? ?? ['General'];
    if (preferredSubjects.isNotEmpty && preferredSubjects.first != 'General') {
      _activityItems.add({
        'title': '📚 Dive Deeper into ${preferredSubjects.first}',
        'time': 'This week',
        'icon': Icons.menu_book,
        'color': const Color(0xFF6C5CE7),
        'detail': 'Explore more content in your favorite subject',
        'relevance': 8,
      });
    }
  }

  DateTime _parseActivityDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now().subtract(const Duration(days: 1));
      }
    }
    return DateTime.now().subtract(const Duration(days: 1));
  }

  int _calculateActivityRelevance(Map<String, dynamic> activity, Map<String, dynamic> userProfile) {
    int relevance = 5; // Base relevance

    final score = activity['score'] as double? ?? 0.0;
    final subject = activity['subject'] as String? ?? '';
    final timestamp = activity['date'];
    final activityDate = _parseActivityDate(timestamp);
    final hoursAgo = DateTime.now().difference(activityDate).inHours;

    // Recency bonus
    if (hoursAgo < 1) relevance += 3;
    else if (hoursAgo < 6) relevance += 2;
    else if (hoursAgo < 24) relevance += 1;

    // Performance bonus
    if (score >= 90.0) relevance += 2;
    else if (score >= 80.0) relevance += 1;

    // Subject preference bonus
    final preferredSubjects = userProfile['preferredSubjects'] as List<String>? ?? [];
    if (preferredSubjects.contains(subject)) relevance += 2;

    // Learning style alignment
    final learningStyle = userProfile['learningStyle'] as String? ?? '';
    if (learningStyle == 'quick_learner' && score >= 85.0) relevance += 1;
    if (learningStyle == 'challenge_seeker' && score < 70.0) relevance += 1;

    return relevance;
  }

  String _classifyActivityType(Map<String, dynamic> activity, Map<String, dynamic> userProfile) {
    final subject = activity['subject'] as String? ?? '';
    final score = activity['score'] as double? ?? 0.0;
    final questions = activity['questions'] as int? ?? 0;

    if (subject.toLowerCase().contains('trivia')) return 'trivia';
    if (subject.toLowerCase().contains('rme') || subject.toLowerCase().contains('religious')) return 'rme';
    if (subject.toLowerCase().contains('bece') || subject.toLowerCase().contains('past')) return 'past_questions';

    // Classify based on performance patterns
    if (score >= 95.0) return 'mastery';
    if (score >= 80.0) return 'strong_performance';
    if (score < 60.0) return 'needs_improvement';

    // Classify based on question count (study intensity)
    if (questions >= 20) return 'intensive_study';
    if (questions >= 10) return 'focused_study';

    return 'regular_practice';
  }

  Map<String, String> _generateSmartActivityMessage(Map<String, dynamic> activity, String activityType, Map<String, dynamic> userProfile) {
    final subject = activity['subject'] as String? ?? 'General';
    final score = activity['score'] as double? ?? 0.0;
    final questions = activity['questions'] as int? ?? 0;

    String title;
    String detail;

    switch (activityType) {
      case 'trivia':
        title = score >= 80.0 ? '🎯 Trivia Champion!' : '🎮 Trivia Challenge Completed';
        detail = '${score.toStringAsFixed(0)}% score • ${questions} fun questions';
        break;
      case 'rme':
        title = score >= 85.0 ? '🙏 RME Excellence Achieved' : '📖 RME Study Session';
        detail = '${score.toStringAsFixed(0)}% score • ${questions} questions explored';
        break;
      case 'past_questions':
        title = score >= 75.0 ? '📚 BECE Mastery Progress' : '📝 Past Questions Practice';
        detail = '${score.toStringAsFixed(0)}% score • ${questions} exam questions';
        break;
      case 'mastery':
        title = '🏆 Perfect Score Achievement!';
        detail = 'Outstanding performance in $subject • ${questions} questions mastered';
        break;
      case 'strong_performance':
        title = '⭐ Excellent Work in $subject!';
        detail = '${score.toStringAsFixed(0)}% score • Keep up the great performance';
        break;
      case 'needs_improvement':
        title = '📈 Growth Opportunity in $subject';
        detail = '${score.toStringAsFixed(0)}% score • Review and try again for better results';
        break;
      case 'intensive_study':
        title = '🔥 Intensive Study Session Complete!';
        detail = 'Covered ${questions} questions in $subject • Impressive dedication';
        break;
      default:
        title = '$subject Quiz Completed';
        detail = '${score.toStringAsFixed(0)}% score • ${questions} questions answered';
    }

    return {'title': title, 'detail': detail};
  }

  Map<String, dynamic> _getActivityDisplayConfig(String activityType, double score, bool isRecent) {
    IconData icon;
    Color color;

    switch (activityType) {
      case 'trivia':
        icon = Icons.psychology;
        color = score >= 80.0 ? const Color(0xFFFF9800) : const Color(0xFFE91E63);
        break;
      case 'rme':
        icon = Icons.book;
        color = score >= 85.0 ? const Color(0xFF6C5CE7) : const Color(0xFF2196F3);
        break;
      case 'past_questions':
        icon = Icons.history_edu;
        color = score >= 75.0 ? const Color(0xFF4CAF50) : const Color(0xFF8BC34A);
        break;
      case 'mastery':
        icon = Icons.stars;
        color = const Color(0xFFFFD700);
        break;
      case 'strong_performance':
        icon = Icons.thumb_up;
        color = const Color(0xFF4CAF50);
        break;
      case 'needs_improvement':
        icon = Icons.trending_up;
        color = const Color(0xFFFF9800);
        break;
      case 'intensive_study':
        icon = Icons.local_fire_department;
        color = const Color(0xFFFF5722);
        break;
      default:
        icon = Icons.quiz;
        color = isRecent ? const Color(0xFF2196F3) : const Color(0xFF9E9E9E);
    }

    return {'icon': icon, 'color': color};
  }

  void _addContextualMotivationalActivities() {
    final profile = _userBehaviorProfile;
    final engagementLevel = profile['engagementLevel'] as String? ?? 'needs_encouragement';
    final currentStreak = this.currentStreak;

    // Add motivational activities based on context
    if (engagementLevel == 'highly_engaged' && currentStreak >= 3) {
      _activityItems.add({
        'title': '🔥 You\'re on Fire! Keep the Streak Alive',
        'time': 'Motivational',
        'icon': Icons.local_fire_department,
        'color': const Color(0xFFFF5722),
        'detail': '$currentStreak-day streak! Every day counts toward your goals',
        'relevance': 7,
        'type': 'motivational',
      });
    }

    if (overallProgress >= 80.0 && questionsAnswered >= 10) {
      _activityItems.add({
        'title': '🎓 Academic Excellence in Progress',
        'time': 'Achievement',
        'icon': Icons.school,
        'color': const Color(0xFF4CAF50),
        'detail': '${overallProgress.toStringAsFixed(0)}% average! You\'re performing exceptionally well',
        'relevance': 6,
        'type': 'achievement',
      });
    }
  }

  void _addFallbackActivity() {
    final fallbackActivities = [
      {
        'title': '📖 Explore Our Digital Library',
        'time': 'Available',
        'icon': Icons.library_books,
        'color': const Color(0xFF6C5CE7),
        'detail': 'Discover textbooks, storybooks, and study materials',
        'relevance': 3,
      },
      {
        'title': '👥 Join the Leaderboard Community',
        'time': 'Social',
        'icon': Icons.emoji_events,
        'color': const Color(0xFFFF9800),
        'detail': 'Compete with other students and track your ranking',
        'relevance': 3,
      },
      {
        'title': '🎯 Set Daily Learning Goals',
        'time': 'Planning',
        'icon': Icons.flag,
        'color': const Color(0xFF2196F3),
        'detail': 'Establish targets and celebrate your progress',
        'relevance': 3,
      },
    ];

    // Add a random fallback activity
    final randomIndex = DateTime.now().millisecondsSinceEpoch % fallbackActivities.length;
    _activityItems.add(fallbackActivities[randomIndex]);
  }

  void _detectAchievements() {
    _userAchievements = [];
    final userProfile = _userBehaviorProfile;
    final learningStyle = userProfile['learningStyle'] as String? ?? 'explorer';
    final engagementLevel = userProfile['engagementLevel'] as String? ?? 'needs_encouragement';
    final performanceTrends = userProfile['performanceTrends'] as Map<String, dynamic>? ?? {};
    final trend = performanceTrends['trend'] as String? ?? 'stable';

    // Dynamic achievement detection based on user behavior patterns

    // Study Streak Achievements with ML insights
    if (currentStreak >= 30) {
      _userAchievements.add(_createSmartAchievement(
        'Monthly Champion',
        Icons.local_fire_department,
        Colors.red,
        '30-day streak! Unmatched dedication detected',
        'streak_master',
        10,
      ));
    } else if (currentStreak >= 14) {
      _userAchievements.add(_createSmartAchievement(
        'Fortnight Hero',
        Icons.local_fire_department,
        Colors.orange,
        '14-day streak! Building excellent habits',
        'streak_expert',
        9,
      ));
    } else if (currentStreak >= 7) {
      _userAchievements.add(_createSmartAchievement(
        'Week Warrior',
        Icons.local_fire_department,
        Colors.orange,
        '7-day streak! Consistency is your superpower',
        'streak_warrior',
        8,
      ));
    } else if (currentStreak >= 3) {
      _userAchievements.add(_createSmartAchievement(
        'Getting Started',
        Icons.local_fire_department,
        Colors.yellow.shade700,
        '$currentStreak-day streak! Momentum is building',
        'streak_starter',
        7,
      ));
    }

    // Performance Achievements with trend analysis
    if (overallProgress >= 95.0 && questionsAnswered >= 10) {
      _userAchievements.add(_createSmartAchievement(
        'Perfect Scholar',
        Icons.star,
        Colors.purple,
        '95%+ average! Elite performance detected',
        'perfectionist',
        10,
      ));
    } else if (overallProgress >= 85.0 && questionsAnswered >= 5) {
      final trendBonus = trend == 'improving' ? ' and improving!' : '!';
      _userAchievements.add(_createSmartAchievement(
        'High Achiever',
        Icons.star,
        Colors.blue,
        '85%+ average$trendBonus',
        'high_performer',
        9,
      ));
    } else if (trend == 'improving' && overallProgress >= 70.0) {
      _userAchievements.add(_createSmartAchievement(
        'Rising Star',
        Icons.trending_up,
        Colors.green,
        'Performance trending upward! Keep it up',
        'improver',
        8,
      ));
    }

    // Subject-specific achievements
    _addSubjectSpecificAchievements();

    // Learning style achievements
    _addLearningStyleAchievements(learningStyle);

    // Engagement-based achievements
    _addEngagementAchievements(engagementLevel);

    // Quiz mastery achievements
    if (questionsAnswered >= 100) {
      _userAchievements.add(_createSmartAchievement(
        'Century Club',
        Icons.numbers,
        Colors.indigo,
        '100+ questions answered! True dedication',
        'century_club',
        9,
      ));
    } else if (questionsAnswered >= 50) {
      _userAchievements.add(_createSmartAchievement(
        'Quiz Master',
        Icons.quiz,
        Colors.blue,
        '50+ questions! You\'re a quiz expert',
        'quiz_master',
        8,
      ));
    } else if (questionsAnswered >= 25) {
      _userAchievements.add(_createSmartAchievement(
        'Knowledge Seeker',
        Icons.quiz,
        Colors.teal,
        '25+ questions! Building solid foundations',
        'knowledge_seeker',
        7,
      ));
    } else if (questionsAnswered >= 10) {
      _userAchievements.add(_createSmartAchievement(
        'First Steps',
        Icons.quiz,
        Colors.green,
        '10+ questions! Welcome to the learning journey',
        'first_steps',
        6,
      ));
    }

    // Past Questions Achievements with predictive insights
    if (pastQuestionsProgress >= 90.0 && pastQuestionsAnswered >= 10) {
      _userAchievements.add(_createSmartAchievement(
        'BECE Expert',
        Icons.school,
        Colors.indigo,
        '90%+ on past questions! Exam-ready performance',
        'bece_expert',
        9,
      ));
    } else if (pastQuestionsAnswered >= 20) {
      _userAchievements.add(_createSmartAchievement(
        'Past Questions Pro',
        Icons.history_edu,
        Colors.brown,
        '20+ past questions! Strong exam preparation',
        'past_questions_pro',
        8,
      ));
    }

    // Trivia Achievements
    if (triviaProgress >= 90.0 && triviaQuestionsAnswered >= 10) {
      _userAchievements.add(_createSmartAchievement(
        'Trivia Genius',
        Icons.psychology,
        Colors.pink,
        '90%+ trivia score! Outstanding general knowledge',
        'trivia_genius',
        8,
      ));
    } else if (triviaQuestionsAnswered >= 25) {
      _userAchievements.add(_createSmartAchievement(
        'Trivia Master',
        Icons.psychology,
        Colors.pink,
        '25+ trivia questions! Knowledge enthusiast',
        'trivia_master',
        7,
      ));
    }

    // XP Achievements with progression insights
    if (userXP >= 10000) {
      _userAchievements.add(_createSmartAchievement(
        'XP Champion',
        Icons.flash_on,
        Colors.yellow.shade800,
        '10,000+ XP! Legendary learner status',
        'xp_champion',
        10,
      ));
    } else if (userXP >= 5000) {
      _userAchievements.add(_createSmartAchievement(
        'XP Hunter',
        Icons.flash_on,
        Colors.amber,
        '5,000+ XP! Elite XP earner',
        'xp_hunter',
        9,
      ));
    } else if (userXP >= 1000) {
      _userAchievements.add(_createSmartAchievement(
        'XP Collector',
        Icons.flash_on,
        Colors.orange,
        '1,000+ XP! Building momentum',
        'xp_collector',
        8,
      ));
    }

    // Rank Achievements with predictive elements
    if (currentRank != null) {
      if (currentRank!.name.toLowerCase().contains('master') ||
          currentRank!.name.toLowerCase().contains('champion')) {
        _userAchievements.add(_createSmartAchievement(
          'Elite Rank',
          Icons.emoji_events,
          Colors.amber.shade700,
          '${currentRank!.name} achieved! Top-tier status',
          'elite_rank',
          9,
        ));
      } else if (currentRank!.name.toLowerCase().contains('expert') ||
                 currentRank!.name.toLowerCase().contains('advanced')) {
        _userAchievements.add(_createSmartAchievement(
          'Advanced Learner',
          Icons.emoji_events,
          Colors.blue.shade700,
          '${currentRank!.name} achieved! Advanced knowledge',
          'advanced_learner',
          8,
        ));
      }
    }

    // Study time achievements
    if (weeklyStudyHours >= 20) {
      _userAchievements.add(_createSmartAchievement(
        'Study Champion',
        Icons.access_time,
        Colors.teal.shade700,
        '20+ hours this week! Unmatched dedication',
        'study_champion',
        9,
      ));
    } else if (weeklyStudyHours >= 10) {
      _userAchievements.add(_createSmartAchievement(
        'Dedicated Student',
        Icons.access_time,
        Colors.teal,
        '10+ hours this week! Strong commitment',
        'dedicated_student',
        8,
      ));
    }

    // Predictive achievements (based on current trajectory)
    _addPredictiveAchievements();

    // Sort achievements by relevance and recency
    _userAchievements.sort((a, b) {
      final aRelevance = a['relevance'] as int? ?? 0;
      final bRelevance = b['relevance'] as int? ?? 0;
      return bRelevance.compareTo(aRelevance);
    });

    // Limit to 5 achievements for display
    if (_userAchievements.length > 5) {
      _userAchievements = _userAchievements.sublist(0, 5);
    }

    // If no achievements yet, show contextual starter achievements
    if (_userAchievements.isEmpty) {
      _addStarterAchievements();
    }
  }

  Map<String, dynamic> _createSmartAchievement(String title, IconData icon, Color color, String description, String type, int relevance) {
    return {
      'title': title,
      'icon': icon,
      'color': color,
      'description': description,
      'type': type,
      'relevance': relevance,
      'unlockedAt': DateTime.now().toIso8601String(),
    };
  }

  void _addSubjectSpecificAchievements() {
    final weakAreas = _userBehaviorProfile['weaknesses'] as List<String>? ?? [];
    final strengths = _userBehaviorProfile['strengths'] as List<String>? ?? [];

    // Subject mastery achievements
    for (var subject in _subjectProgress) {
      if (subject.progress >= 95.0) {
        _userAchievements.add(_createSmartAchievement(
          '${subject.name} Master',
          Icons.grade,
          subject.color,
          '95%+ in ${subject.name}! Subject mastery achieved',
          'subject_master_${subject.name.toLowerCase()}',
          9,
        ));
      } else if (subject.progress >= 85.0) {
        _userAchievements.add(_createSmartAchievement(
          '${subject.name} Expert',
          Icons.school,
          subject.color,
          '85%+ in ${subject.name}! Strong subject knowledge',
          'subject_expert_${subject.name.toLowerCase()}',
          8,
        ));
      }
    }

    // Improvement achievements
    if (weakAreas.isNotEmpty && _subjectProgress.any((s) => s.progress >= 70.0)) {
      _userAchievements.add(_createSmartAchievement(
        'Subject Improver',
        Icons.trending_up,
        Colors.green,
        'Significant improvement in ${weakAreas.first}',
        'subject_improver',
        7,
      ));
    }
  }

  void _addLearningStyleAchievements(String learningStyle) {
    switch (learningStyle) {
      case 'quick_learner':
        if (overallProgress >= 80.0 && questionsAnswered >= 5) {
          _userAchievements.add(_createSmartAchievement(
            'Speed Learner',
            Icons.speed,
            Colors.blue,
            'Quick comprehension! Fast learning style mastered',
            'speed_learner',
            8,
          ));
        }
        break;
      case 'consistent_builder':
        if (currentStreak >= 5 && overallProgress >= 75.0) {
          _userAchievements.add(_createSmartAchievement(
            'Steady Progress',
            Icons.timeline,
            Colors.teal,
            'Consistent improvement! Steady learning approach',
            'steady_progress',
            8,
          ));
        }
        break;
      case 'challenge_seeker':
        if (_recentActivity.any((a) => (a['score'] as double? ?? 0.0) < 60.0) &&
            _recentActivity.any((a) => (a['score'] as double? ?? 0.0) >= 80.0)) {
          _userAchievements.add(_createSmartAchievement(
            'Challenge Conqueror',
            Icons.sports_score,
            Colors.orange,
            'Thrives on challenges! Growth through difficulty',
            'challenge_conqueror',
            8,
          ));
        }
        break;
    }
  }

  void _addEngagementAchievements(String engagementLevel) {
    switch (engagementLevel) {
      case 'highly_engaged':
        _userAchievements.add(_createSmartAchievement(
          'Learning Enthusiast',
          Icons.favorite,
          Colors.red,
          'Highly engaged learner! Passionate about knowledge',
          'learning_enthusiast',
          9,
        ));
        break;
      case 'moderately_engaged':
        _userAchievements.add(_createSmartAchievement(
          'Active Learner',
          Icons.thumb_up,
          Colors.blue,
          'Consistently engaged! Building good habits',
          'active_learner',
          7,
        ));
        break;
    }
  }

  void _addPredictiveAchievements() {
    // Predict and suggest upcoming achievements
    if (currentStreak >= 5 && currentStreak < 7) {
      _userAchievements.add(_createSmartAchievement(
        'Streak Milestone Ahead',
        Icons.local_fire_department,
        Colors.orange.shade300,
        '2 more days to Week Warrior! Keep going',
        'predictive_streak',
        6,
      ));
    }

    if (questionsAnswered >= 40 && questionsAnswered < 50) {
      _userAchievements.add(_createSmartAchievement(
        'Quiz Master Incoming',
        Icons.quiz,
        Colors.blue.shade300,
        '10 more questions to Quiz Master status!',
        'predictive_quiz_master',
        6,
      ));
    }

    if (nextRank != null) {
      final xpNeeded = nextRank!.minXP - userXP;
      if (xpNeeded <= 1000) {
        _userAchievements.add(_createSmartAchievement(
          '${nextRank!.name} Within Reach',
          Icons.emoji_events,
          nextRank!.getTierColor().withOpacity(0.7),
          '${xpNeeded}XP to ${nextRank!.name}! Almost there',
          'predictive_rank',
          7,
        ));
      }
    }
  }

  void _addStarterAchievements() {
    final achievements = [
      _createSmartAchievement(
        'Welcome Aboard!',
        Icons.waving_hand,
        Colors.green,
        'Joined Uriel Academy! Your learning journey begins',
        'welcome',
        5,
      ),
      _createSmartAchievement(
        'First Quiz Awaits',
        Icons.play_arrow,
        Colors.blue,
        'Ready for your first quiz? Knowledge awaits!',
        'first_quiz_ready',
        4,
      ),
      _createSmartAchievement(
        'Library Explorer',
        Icons.menu_book,
        Colors.purple,
        'Explore our digital library of textbooks and storybooks',
        'library_explorer',
        4,
      ),
      _createSmartAchievement(
        'Community Member',
        Icons.people,
        Colors.orange,
        'Part of the Uriel Academy learning community',
        'community_member',
        3,
      ),
    ];

    _userAchievements.addAll(achievements);
  }

  void _generateStudyRecommendations() {
    _studyRecommendations = [];
    final userProfile = _userBehaviorProfile;
    final learningStyle = userProfile['learningStyle'] as String? ?? 'explorer';
    final engagementLevel = userProfile['engagementLevel'] as String? ?? 'needs_encouragement';
    final studyPatterns = userProfile['studyPatterns'] as Map<String, dynamic>? ?? {};
    final performanceTrends = userProfile['performanceTrends'] as Map<String, dynamic>? ?? {};
    final weakAreas = userProfile['weaknesses'] as List<String>? ?? [];
    final strengths = userProfile['strengths'] as List<String>? ?? [];
    final preferredSubjects = userProfile['preferredSubjects'] as List<String>? ?? [];

    // ML-powered recommendation engine

    // 1. Subject-specific recommendations with predictive analytics
    if (weakAreas.isNotEmpty) {
      final primaryWeakArea = weakAreas.first;
      final weakSubjectProgress = _subjectProgress.firstWhere(
        (s) => s.name == primaryWeakArea,
        orElse: () => SubjectProgress(primaryWeakArea, 0.0, Colors.grey),
      );

      if (weakSubjectProgress.progress < 50.0) {
        _studyRecommendations.add('🚨 Critical Focus: ${primaryWeakArea} needs immediate attention. Dedicate extra study time to improve from ${weakSubjectProgress.progress.toStringAsFixed(0)}%');
      } else {
        _studyRecommendations.add('📈 Growth Zone: ${primaryWeakArea} shows improvement potential. Targeted practice will yield quick results');
      }
    }

    // 2. Learning style-based recommendations
    switch (learningStyle) {
      case 'quick_learner':
        if (overallProgress >= 80.0) {
          _studyRecommendations.add('🧠 Advanced Challenge: Your quick learning style thrives on complexity. Try advanced topics in ${preferredSubjects.isNotEmpty ? preferredSubjects.first : 'your favorite subjects'}');
        } else {
          _studyRecommendations.add('⚡ Speed Learning: Leverage your quick comprehension! Focus on understanding concepts deeply rather than memorizing');
        }
        break;
      case 'consistent_builder':
        if (currentStreak < 5) {
          _studyRecommendations.add('🔄 Build Consistency: Your learning style benefits from regular practice. Aim for daily 15-minute sessions to build momentum');
        } else {
          _studyRecommendations.add('📊 Steady Progress: Your consistent approach is working! Maintain this pattern while gradually increasing difficulty');
        }
        break;
      case 'challenge_seeker':
        _studyRecommendations.add('🎯 Challenge Seeker: You excel when pushed! Seek out difficult questions and complex problems in ${preferredSubjects.isNotEmpty ? preferredSubjects.first : 'challenging subjects'}');
        break;
    }

    // 3. Engagement-based motivation
    switch (engagementLevel) {
      case 'highly_engaged':
        _studyRecommendations.add('⭐ Elite Performer: Your dedication is exceptional! Consider mentoring others or exploring advanced certifications');
        break;
      case 'moderately_engaged':
        _studyRecommendations.add('💪 Stay Motivated: You\'re on the right track! Set small daily goals to maintain and increase your engagement level');
        break;
      case 'needs_encouragement':
        _studyRecommendations.add('🌱 Start Small: Begin with 10 minutes daily. Small consistent efforts compound into remarkable results over time');
        break;
    }

    // 4. Study pattern optimization
    final frequency = studyPatterns['frequency'] as String? ?? 'low';
    final consistency = studyPatterns['consistency'] as String? ?? 'irregular';

    if (frequency == 'high' && consistency == 'excellent') {
      _studyRecommendations.add('🏆 Study Master: Your patterns are optimal! Focus on quality over quantity and explore interdisciplinary connections');
    } else if (frequency == 'low') {
      _studyRecommendations.add('⏰ Study Rhythm: Establish a consistent study schedule. Even 20 minutes daily creates powerful learning momentum');
    } else if (consistency == 'needs_improvement') {
      _studyRecommendations.add('📅 Routine Builder: Create a study routine that fits your lifestyle. Consistency beats intensity for long-term success');
    }

    // 5. Performance trend analysis and recommendations
    final trend = performanceTrends['trend'] as String? ?? 'insufficient_data';
    final improvementRate = performanceTrends['improvement_rate'] as double? ?? 0.0;

    switch (trend) {
      case 'improving':
        _studyRecommendations.add('📈 Trending Up: ${improvementRate.abs().toStringAsFixed(1)}% improvement detected! Keep doing what works and accelerate your progress');
        break;
      case 'declining':
        _studyRecommendations.add('🔄 Course Correction: Recent scores show a dip. Review recent quizzes and identify areas for focused improvement');
        break;
      case 'stable':
        if (overallProgress >= 80.0) {
          _studyRecommendations.add('🎯 Performance Plateau: Excellent stable performance! Introduce variety and challenges to continue growing');
        } else {
          _studyRecommendations.add('📊 Steady Foundation: Building solid fundamentals. Focus on understanding core concepts for breakthrough improvement');
        }
        break;
    }

    // 6. Subject variety and balance
    if (_subjectProgress.length < 3 && questionsAnswered >= 15) {
      _studyRecommendations.add('🌟 Subject Diversity: Explore different subjects to build well-rounded knowledge. Interdisciplinary learning enhances understanding');
    }

    // 7. Time management insights
    if (weeklyStudyHours < 3 && questionsAnswered >= 10) {
      _studyRecommendations.add('⏱️ Time Investment: Increase study time gradually. Quality learning requires consistent time investment for lasting retention');
    } else if (weeklyStudyHours > 15) {
      _studyRecommendations.add('⚖️ Balance Check: Excellent dedication! Remember to balance intense study with rest and reflection for optimal learning');
    }

    // 8. Past questions specific advice with predictive elements
    if (pastQuestionsAnswered > 0) {
      if (pastQuestionsProgress < 70.0) {
        _studyRecommendations.add('📚 Exam Preparation: Past questions are crucial for BECE success. Focus on understanding patterns and time management strategies');
      } else if (pastQuestionsProgress >= 85.0) {
        _studyRecommendations.add('🎓 Exam Ready: Strong BECE preparation! Focus on revision techniques and mock exam simulations for peak performance');
      }
    } else if (questionsAnswered >= 10) {
      _studyRecommendations.add('📖 BECE Foundation: Start practicing past questions now. They provide invaluable insight into exam patterns and expectations');
    }

    // 9. Trivia engagement for knowledge breadth
    if (triviaQuestionsAnswered == 0 && questionsAnswered >= 5) {
      _studyRecommendations.add('🎮 Knowledge Games: Trivia questions build general knowledge and make learning enjoyable. Try some fun challenges!');
    } else if (triviaProgress >= 80.0 && triviaQuestionsAnswered >= 10) {
      _studyRecommendations.add('🌍 Knowledge Master: Excellent general knowledge! Continue exploring diverse topics for well-rounded intellectual development');
    }

    // 10. Rank progression guidance
    if (nextRank != null) {
      final xpToNext = nextRank!.minXP - userXP;
      if (xpToNext <= 500) {
        _studyRecommendations.add('🏅 Rank Advancement: Just ${xpToNext}XP from ${nextRank!.name}! Focus on high-scoring quizzes to level up quickly');
      } else if (xpToNext <= 2000) {
        _studyRecommendations.add('🎯 Rank Journey: ${nextRank!.name} is within reach! Consistent performance will get you there faster than you think');
      }
    }

    // 11. Adaptive difficulty recommendations
    if (overallProgress >= 90.0 && _recentActivity.any((a) => (a['score'] as double? ?? 0.0) >= 95.0)) {
      _studyRecommendations.add('🚀 Difficulty Scaling: You\'re ready for advanced challenges! Seek out complex problems that push your intellectual boundaries');
    } else if (overallProgress < 60.0 && questionsAnswered >= 20) {
      _studyRecommendations.add('🛡️ Foundation Building: Focus on fundamentals first. Strong basics create the foundation for advanced learning');
    }

    // 12. Study streak maintenance
    if (currentStreak == 0 && questionsAnswered > 0) {
      _studyRecommendations.add('🔥 Streak Starter: Begin a daily study habit. Even short sessions create powerful momentum and build lasting learning habits');
    } else if (currentStreak > 0 && currentStreak < 7) {
      _studyRecommendations.add('⚡ Momentum Builder: ${currentStreak}-day streak in progress! Each day adds to your learning momentum and confidence');
    } else if (currentStreak >= 7) {
      _studyRecommendations.add('🏆 Habit Champion: ${currentStreak}-day streak! You\'ve built an impressive learning habit. This consistency will carry you far');
    }

    // 13. Personalized subject focus
    if (strengths.isNotEmpty && strengths.length >= 2) {
      _studyRecommendations.add('💎 Subject Strengths: Excel in ${strengths.take(2).join(' and ')}! Use these strengths to help others and explore advanced topics');
    }

    // 14. Predictive learning path
    if (questionsAnswered >= 50 && overallProgress >= 75.0) {
      _studyRecommendations.add('🎓 Advanced Learning: Ready for advanced topics! Consider exploring specialized areas or helping mentor fellow students');
    }

    // 15. Contextual timing advice
    final now = DateTime.now();
    final hour = now.hour;
    if (hour >= 6 && hour < 12) {
      _studyRecommendations.add('🌅 Morning Excellence: Studies show morning learning improves retention by 20%. Perfect timing for focused study sessions');
    } else if (hour >= 18 && hour < 22) {
      _studyRecommendations.add('🌙 Evening Mastery: Your brain is primed for learning. Use this peak cognitive time for complex problem-solving');
    }

    // Remove duplicates and prioritize
    _studyRecommendations = _studyRecommendations.toSet().toList();

    // Sort by relevance (ML-powered prioritization)
    _studyRecommendations.sort((a, b) {
      final aPriority = _calculateRecommendationPriority(a, userProfile);
      final bPriority = _calculateRecommendationPriority(b, userProfile);
      return bPriority.compareTo(aPriority);
    });

    // Limit to 4 recommendations for optimal UX
    if (_studyRecommendations.length > 4) {
      _studyRecommendations = _studyRecommendations.sublist(0, 4);
    }

    // Ensure minimum recommendations
    while (_studyRecommendations.length < 3) {
      if (!_studyRecommendations.any((rec) => rec.contains('quiz'))) {
        _studyRecommendations.add('📝 Practice Makes Perfect: Regular quiz practice strengthens memory retention and builds confidence');
      } else if (!_studyRecommendations.any((rec) => rec.contains('book'))) {
        _studyRecommendations.add('📖 Theory + Practice: Combine textbook reading with quizzes for comprehensive subject mastery');
      } else {
        _studyRecommendations.add('🎯 Goal Setting: Set specific, achievable learning goals to maintain motivation and track progress');
      }
    }
  }

  int _calculateRecommendationPriority(String recommendation, Map<String, dynamic> userProfile) {
    int priority = 5; // Base priority

    // High priority recommendations
    if (recommendation.contains('Critical') || recommendation.contains('🚨')) {
      priority += 5;
    } else if (recommendation.contains('improvement') || recommendation.contains('Focus')) {
      priority += 3;
    }

    // Medium priority based on user state
    final engagementLevel = userProfile['engagementLevel'] as String? ?? '';
    if (engagementLevel == 'needs_encouragement' && recommendation.contains('Start Small')) {
      priority += 3;
    }

    // Learning style alignment
    final learningStyle = userProfile['learningStyle'] as String? ?? '';
    if (learningStyle == 'quick_learner' && recommendation.contains('Advanced')) {
      priority += 2;
    } else if (learningStyle == 'consistent_builder' && recommendation.contains('Consistency')) {
      priority += 2;
    }

    // Recency and relevance
    if (recommendation.contains('Today') || recommendation.contains('Now')) {
      priority += 1;
    }

    return priority;
  }

  void _analyzeUserBehaviorProfile() {
    // Create a behavior profile based on user activity patterns
    _userBehaviorProfile = {
      'learningStyle': _determineLearningStyle(),
      'preferredSubjects': _getPreferredSubjects(),
      'studyPatterns': _analyzeStudyPatterns(),
      'performanceTrends': _calculatePerformanceTrends(),
      'engagementLevel': _measureEngagementLevel(),
      'weaknesses': _identifyWeakAreas(),
      'strengths': _identifyStrengthAreas(),
    };

    // Generate personalized content based on behavior profile
    _generatePersonalizedContent();
  }

  String _determineLearningStyle() {
    // Analyze quiz performance patterns to determine learning style
    if (_recentActivity.isEmpty) return 'explorer';

    int quickLearners = 0;
    int consistentLearners = 0;
    int challengeSeekers = 0;

    for (var activity in _recentActivity) {
      final score = activity['score'] ?? 0.0;
      final questions = activity['questions'] ?? 0;

      if (score >= 85.0 && questions >= 5) {
        quickLearners++;
      } else if (score >= 70.0 && score < 85.0) {
        consistentLearners++;
      } else if (score < 70.0 && questions >= 8) {
        challengeSeekers++;
      }
    }

    if (quickLearners > consistentLearners && quickLearners > challengeSeekers) {
      return 'quick_learner';
    } else if (consistentLearners > challengeSeekers) {
      return 'consistent_builder';
    } else {
      return 'challenge_seeker';
    }
  }

  List<String> _getPreferredSubjects() {
    if (_subjectProgress.isEmpty) return ['General'];

    // Sort subjects by performance (highest first)
    final sortedSubjects = List<SubjectProgress>.from(_subjectProgress)
      ..sort((a, b) => b.progress.compareTo(a.progress));

    return sortedSubjects.take(3).map((s) => s.name).toList();
  }

  Map<String, dynamic> _analyzeStudyPatterns() {
    if (_recentActivity.isEmpty) {
      return {'frequency': 'low', 'consistency': 'irregular', 'peak_times': 'unknown'};
    }

    // Analyze activity frequency
    final recentCount = _recentActivity.length;
    final frequency = recentCount >= 5 ? 'high' : recentCount >= 2 ? 'medium' : 'low';

    // Analyze consistency (based on streak)
    final consistency = currentStreak >= 7 ? 'excellent' :
                       currentStreak >= 3 ? 'good' : 'needs_improvement';

    return {
      'frequency': frequency,
      'consistency': consistency,
      'peak_times': 'evening', // Could be enhanced with actual time analysis
      'preferred_quiz_length': questionsAnswered > 0 ? (questionsAnswered / _recentActivity.length).round() : 5,
    };
  }

  Map<String, dynamic> _calculatePerformanceTrends() {
    if (_recentActivity.length < 3) {
      return {'trend': 'insufficient_data', 'improvement_rate': 0.0};
    }

    // Calculate trend based on recent scores
    final recentScores = _recentActivity.map((a) => a['score'] as double).toList();
    final avgRecent = recentScores.reduce((a, b) => a + b) / recentScores.length;

    final trend = avgRecent >= overallProgress + 5.0 ? 'improving' :
                  avgRecent <= overallProgress - 5.0 ? 'declining' : 'stable';

    final improvementRate = ((avgRecent - overallProgress) / overallProgress * 100);

    return {
      'trend': trend,
      'improvement_rate': improvementRate,
      'recent_average': avgRecent,
      'overall_average': overallProgress,
    };
  }

  String _measureEngagementLevel() {
    final factors = [
      currentStreak >= 7 ? 3 : currentStreak >= 3 ? 2 : 1,
      questionsAnswered >= 50 ? 3 : questionsAnswered >= 20 ? 2 : 1,
      weeklyStudyHours >= 10 ? 3 : weeklyStudyHours >= 5 ? 2 : 1,
      overallProgress >= 80.0 ? 3 : overallProgress >= 60.0 ? 2 : 1,
    ];

    final avgEngagement = factors.reduce((a, b) => a + b) / factors.length;

    if (avgEngagement >= 2.5) return 'highly_engaged';
    if (avgEngagement >= 1.8) return 'moderately_engaged';
    return 'needs_encouragement';
  }

  List<String> _identifyWeakAreas() {
    return _subjectProgress
        .where((subject) => subject.progress < 65.0)
        .map((subject) => subject.name)
        .toList();
  }

  List<String> _identifyStrengthAreas() {
    return _subjectProgress
        .where((subject) => subject.progress >= 80.0)
        .map((subject) => subject.name)
        .toList();
  }

  void _generatePersonalizedContent() {
    _personalizedContent = [];

    final profile = _userBehaviorProfile;
    final learningStyle = profile['learningStyle'] as String;
    final engagementLevel = profile['engagementLevel'] as String;
    final studyPatterns = profile['studyPatterns'] as Map<String, dynamic>;
    final performanceTrends = profile['performanceTrends'] as Map<String, dynamic>;
    final preferredSubjects = profile['preferredSubjects'] as List<String>;
    final weakAreas = profile['weaknesses'] as List<String>;
    final strengths = profile['strengths'] as List<String>;

    // Generate personalized content based on behavior profile

    // 1. Learning style-based recommendations
    switch (learningStyle) {
      case 'quick_learner':
        _personalizedContent.add('🚀 Quick Learner: You excel at grasping concepts fast! Try advanced topics in ${preferredSubjects.first}');
        break;
      case 'consistent_builder':
        _personalizedContent.add('📈 Steady Builder: Your consistent approach is paying off! Keep building on your ${preferredSubjects.first} foundation');
        break;
      case 'challenge_seeker':
        _personalizedContent.add('🎯 Challenge Seeker: You thrive on difficult questions! Push your limits with complex ${preferredSubjects.first} problems');
        break;
    }

    // 2. Engagement-based motivation
    switch (engagementLevel) {
      case 'highly_engaged':
        _personalizedContent.add('⭐ Champion: Your dedication is inspiring! You\'re on track to master ${preferredSubjects.take(2).join(' and ')}');
        break;
      case 'moderately_engaged':
        _personalizedContent.add('💪 Keep Going: You\'re making great progress! A little more consistency will take you far');
        break;
      case 'needs_encouragement':
        _personalizedContent.add('🌱 Start Small: Every expert was once a beginner. Take one quiz today to build momentum!');
        break;
    }

    // 3. Study pattern insights
    final frequency = studyPatterns['frequency'] as String;
    final consistency = studyPatterns['consistency'] as String;

    if (frequency == 'high' && consistency == 'excellent') {
      _personalizedContent.add('🔥 Study Master: Your ${currentStreak}-day streak shows incredible discipline! You\'re unstoppable');
    } else if (frequency == 'low') {
      _personalizedContent.add('⏰ Study Time: Regular practice (even 15 minutes daily) leads to remarkable improvement');
    }

    // 4. Performance trend analysis
    final trend = performanceTrends['trend'] as String;
    final improvementRate = performanceTrends['improvement_rate'] as double;

    if (trend == 'improving') {
      _personalizedContent.add('📊 Trending Up: ${improvementRate.toStringAsFixed(1)}% improvement! Your hard work is showing results');
    } else if (trend == 'declining') {
      _personalizedContent.add('📉 Focus Time: Let\'s turn things around. Review your weak areas and practice consistently');
    }

    // 5. Subject-specific insights
    if (weakAreas.isNotEmpty) {
      _personalizedContent.add('🎯 Growth Areas: Focus on ${weakAreas.take(2).join(' and ')} - targeted practice will boost your scores');
    }

    if (strengths.isNotEmpty && strengths.length >= 2) {
      _personalizedContent.add('🏆 Subject Stars: You\'re excelling in ${strengths.take(2).join(' and ')}! Teach others or explore advanced topics');
    }

    // 6. Smart timing suggestions
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 12) {
      _personalizedContent.add('🌅 Morning Mind: Studies show morning study sessions improve retention by 20%. Perfect timing!');
    } else if (hour >= 18 && hour < 22) {
      _personalizedContent.add('🌙 Evening Excellence: Your brain is primed for learning. Make the most of peak cognitive hours');
    }

    // 7. Achievement predictions
    if (userXP > 0) {
      final predictedRank = _predictNextAchievement();
      if (predictedRank != null) {
        _personalizedContent.add('🎖️ Next Milestone: Keep going! You\'re on track to reach $predictedRank soon');
      }
    }

    // Ensure we have at least 3 personalized items
    while (_personalizedContent.length < 3) {
      if (!_personalizedContent.any((item) => item.contains('quiz'))) {
        _personalizedContent.add('📚 Knowledge Builder: Each quiz you complete adds to your growing expertise');
      } else if (!_personalizedContent.any((item) => item.contains('streak'))) {
        _personalizedContent.add('🔥 Habit Hero: Building daily study habits creates lifelong learning success');
      } else {
        _personalizedContent.add('🎓 Learning Journey: Every question answered brings you closer to academic excellence');
      }
    }

    // Limit to 3 for dashboard display
    if (_personalizedContent.length > 3) {
      _personalizedContent = _personalizedContent.sublist(0, 3);
    }
  }

  String? _predictNextAchievement() {
    // Predict next likely achievement based on current progress
    if (currentStreak >= 5 && currentStreak < 7) {
      return '7-Day Streak';
    } else if (questionsAnswered >= 20 && questionsAnswered < 50) {
      return 'Quiz Master (50 questions)';
    } else if (overallProgress >= 75 && overallProgress < 85) {
      return 'High Achiever (85% average)';
    } else if (nextRank != null) {
      return nextRank!.name;
    }
    return null;
  }

  double _calculateScoreTrend() {
    if (_recentActivity.length < 3) return 0.0;

    // Calculate trend based on recent vs overall performance
    final recentScores = _recentActivity.map((a) => a['score'] as double).toList();
    final avgRecent = recentScores.reduce((a, b) => a + b) / recentScores.length;

    // Return positive for improving, negative for declining
    final trend = avgRecent - overallProgress;
    return trend > 2.0 ? 1.0 : trend < -2.0 ? -1.0 : 0.0;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return '1 day ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) return '${(difference.inDays / 7).round()} weeks ago';
      return '${(difference.inDays / 30).round()} months ago';
    } else if (difference.inHours > 0) {
      if (difference.inHours == 1) return '1 hour ago';
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      if (difference.inMinutes == 1) return '1 minute ago';
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  String _getNameFromEmail(String? email) {
    if (email == null) return 'Student';
    final emailPart = email.split('@').first;
    if (emailPart.length >= 5) {
      return emailPart.substring(0, 5);
    }
    return emailPart;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        // Prevent going back to landing/login page
        // Show exit confirmation dialog instead
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Exit App?',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            content: Text(
              'Are you sure you want to exit?',
              style: GoogleFonts.montserrat(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.montserrat(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                ),
                child: Text('Exit', style: GoogleFonts.montserrat()),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldExit == true) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFE),
          body: Stack(
            children: [
              SafeArea(
                child: isSmallScreen 
                    ? Column(
                        children: [
                          // Mobile Header
                          _buildMobileHeader(),
                          
                          // Mobile Content
                          Expanded(
                            child: _showingProfile 
                                ? const StudentProfilePage()
                                : IndexedStack(
                                    index: _selectedIndex,
                                    children: [
                                      _buildDashboard(),
                                      _buildQuestionsPage(),
                                      _buildTextbooksPage(),
                                      _buildTriviaPage(),
                                      const RedesignedLeaderboardPage(),
                                      _buildFeedbackPage(),
                                    ],
                                  ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Desktop Sidebar Navigation
                          _buildSideNavigation(),
                          
                          // Desktop Main Content
                          Expanded(
                            child: Column(
                              children: [
                                // Desktop Header
                                _buildHeader(context),
                                
                                // Desktop Content Area
                                Expanded(
                                  child: _showingProfile 
                                      ? const StudentProfilePage()
                                      : IndexedStack(
                                          index: _selectedIndex,
                                          children: [
                                            _buildDashboard(),
                                            _buildQuestionsPage(),
                                            _buildTextbooksPage(),
                                            _buildTriviaPage(),
                                            const RedesignedLeaderboardPage(),
                                            _buildFeedbackPage(),
                                          ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
              
              // Connection Status Indicator
              StreamBuilder<bool>(
                stream: ConnectionService().connectionStatus,
                builder: (context, snapshot) {
                  if (snapshot.hasData && !snapshot.data!) {
                    return _buildConnectionBanner();
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          
          // Bottom Navigation (Mobile Only)
          bottomNavigationBar: isSmallScreen ? _buildBottomNavigation() : null,
          );
        },
      ),
    );
  }

  // Connection status banner
  Widget _buildConnectionBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: Colors.orange.shade700,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connection lost. Reconnecting...',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Attempt manual reconnection
                  await ConnectionService().forceReconnect();
                  await AuthService().refreshCurrentUserToken();
                },
                child: Text(
                  'Retry',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo and Title
          Text(
            'Uriel Academy',
            style: AppStyles.brandNameLight(fontSize: 18),
          ),
          
          const Spacer(),
          
          // User Rank Badge (smaller than profile)
          GestureDetector(
            onTap: () => _showRankDialog(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: currentRank != null 
                      ? currentRank!.getTierColor().withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentRank != null 
                        ? currentRank!.getTierColor().withOpacity(0.15)
                        : Colors.grey.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                backgroundImage: currentRank != null && currentRank!.imageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(currentRank!.imageUrl)
                    : null,
                child: currentRank == null || currentRank!.imageUrl.isEmpty
                    ? Icon(
                        currentRank != null ? Icons.emoji_events : Icons.emoji_events_outlined,
                        color: currentRank?.getTierColor() ?? Colors.grey,
                        size: 16,
                      )
                    : null,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Profile Avatar (larger than badge)
          GestureDetector(
            onTap: () => _showProfileMenu(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1A1E3F),
              backgroundImage: _getAvatarImage(),
              child: _getAvatarImage() == null ? Text(
                userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Uriel Academy',
              style: AppStyles.brandNameStyle(
                fontSize: 20,
              ),
            ),
          ),
          
          // User Profile Card
          GestureDetector(
            onTap: () => setState(() {
              _showingProfile = !_showingProfile;
              if (_showingProfile) _selectedIndex = 0; // Reset to dashboard when returning
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1A1E3F).withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1A1E3F),
                    backgroundImage: _getAvatarImage(),
                    child: _getAvatarImage() == null ? Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        Text(
                          userClass,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(0, 'Dashboard'),
                  _buildNavItem(1, 'Questions'),
                  _buildNavItem(2, 'Books'),
                  _buildNavItem(3, 'Trivia'),
                  _buildNavItem(4, 'Leaderboard'),
                  _buildNavItem(5, 'Feedback'),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(),
                  ),
                  
                  _buildNavItem(-1, 'Pricing'),
                  _buildNavItem(-7, 'Payment'),
                  _buildNavItem(-2, 'About Us'),
                  _buildNavItem(-3, 'Contact'),
                  _buildNavItem(-4, 'Privacy Policy'),
                  _buildNavItem(-5, 'Terms of Service'),
                  _buildNavItem(-6, 'FAQ'),
                  _buildNavItem(-8, 'All Ranks'),
                ],
              ),
            ),
          ),
          
          // Settings & Theme Toggle
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.grey[600]),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: _handleSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title) {
    final isSelected = _selectedIndex == index;
    final isMainNav = index >= 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
                ? const Color(0xFFD62828)
                : Colors.grey[700],
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFFD62828).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: isMainNav ? () {
          setState(() {
            _selectedIndex = index;
            _showingProfile = false; // Close profile when switching tabs
          });
        } : () => _navigateToFooterPage(title),
      ),
    );
  }
  
  void _navigateToFooterPage(String pageName) {
    // Handle All Ranks page separately
    if (pageName == 'All Ranks') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RedesignedAllRanksPage(userXP: userXP),
        ),
      );
      return;
    }
    
    String route;
    switch (pageName) {
      case 'Pricing':
        route = '/pricing';
        break;
      case 'Payment':
        route = '/payment';
        break;
      case 'About Us':
        route = '/about';
        break;
      case 'Contact':
        route = '/contact';
        break;
      case 'Privacy Policy':
        route = '/privacy';
        break;
      case 'Terms of Service':
        route = '/terms';
        break;
      case 'FAQ':
        route = '/faq';
        break;
      default:
        return;
    }
    Navigator.pushNamed(context, route);
  }

  Widget _buildBottomNavigation() {
    final tabs = [
      {'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
      {'label': 'Questions', 'icon': Icons.quiz_outlined},
      {'label': 'Books', 'icon': Icons.menu_book_outlined},
      {'label': 'Trivia', 'icon': Icons.extension_outlined},
      {'label': 'Leaderboard', 'icon': Icons.emoji_events_outlined},
      {'label': 'Feedback', 'icon': Icons.feedback_outlined},
    ];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedIndex = index;
                  _showingProfile = false;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFD62828).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected 
                        ? Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.3), width: 1)
                        : null,
                  ),
                  child: Text(
                    tabs[index]['label'] as String,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? const Color(0xFFD62828)
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mobile menu button
          if (isSmallScreen) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _showMobileMenu(),
            ),
            const SizedBox(width: 16),
          ],
          
          const Spacer(),
          
          // User Rank Badge (smaller than profile)
          GestureDetector(
            onTap: () => _showRankDialog(),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: currentRank != null 
                      ? currentRank!.getTierColor().withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentRank != null 
                        ? currentRank!.getTierColor().withOpacity(0.15)
                        : Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white,
                backgroundImage: currentRank != null && currentRank!.imageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(currentRank!.imageUrl)
                    : null,
                child: currentRank == null || currentRank!.imageUrl.isEmpty
                    ? Icon(
                        currentRank != null ? Icons.emoji_events : Icons.emoji_events_outlined,
                        color: currentRank?.getTierColor() ?? Colors.grey,
                        size: 20,
                      )
                    : null,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Profile Avatar (larger than badge)
          GestureDetector(
            onTap: () => _showProfileMenu(),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1A1E3F),
              backgroundImage: _getAvatarImage(),
              child: _getAvatarImage() == null ? Text(
                userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isSmallScreen ? 22 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                    ),
                    children: [
                      TextSpan(text: 'Welcome $userName!\n'),
                      TextSpan(
                        text: 'Ready to rise through the ranks? Earn XP and dominate the leaderboards. Start a quiz now!',
                        style: GoogleFonts.montserrat(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Progress Overview Hero Card
          _buildProgressOverviewCard(),
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Rank Progress Card
          if (currentRank != null)
            RankProgressCard(
              currentRank: currentRank!,
              nextRank: nextRank,
              userXP: userXP,
              onViewAllRanks: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RedesignedAllRanksPage(userXP: userXP),
                  ),
                );
              },
            ),
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Performance Metrics & Subject Progress - Mobile Layout
          if (isSmallScreen) ...[
            _buildSubjectProgressCard(),
            const SizedBox(height: 16),
            _buildRecentActivityCard(),
            const SizedBox(height: 16),
            _buildPastQuestionsCard(),
            const SizedBox(height: 16),
            _buildQuickStatsCard(),
            const SizedBox(height: 16),
            _buildUpcomingDeadlines(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
          ] else ...[
            // Desktop Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSubjectProgressCard(),
                      const SizedBox(height: 16),
                      _buildRecentActivityCard(),
                      const SizedBox(height: 16),
                      _buildPastQuestionsCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildQuickStatsCard(),
                      const SizedBox(height: 16),
                      _buildUpcomingDeadlines(),
                      const SizedBox(height: 16),
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Recent Achievements
          _buildRecentAchievements(),
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // AI Recommendations
          _buildAIRecommendations(),
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Smart Insights (ML-powered personalization)
          _buildSmartInsights(),
          
          // Add extra bottom padding for mobile to account for bottom navigation
          if (isSmallScreen) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProgressOverviewCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1E3F).withValues(alpha: 0.3),
            blurRadius: isSmallScreen ? 15 : 20,
            offset: Offset(0, isSmallScreen ? 6 : 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row - Stack on mobile if needed
          if (isSmallScreen) ...[
            Text(
              'Your Progress Overview',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'This Week',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Progress Overview',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'This Week',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Progress metrics - Stack on mobile, row on desktop
          if (isSmallScreen) ...[
            // Mobile: Stack metrics vertically with 2 columns
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    'Average Score',
                    '${overallProgress.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    overallProgress / 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProgressMetric(
                    'Study Streak',
                    '$currentStreak days',
                    Icons.local_fire_department,
                    currentStreak / 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressMetric(
              'Study Hours',
              '${weeklyStudyHours}h this week',
              Icons.access_time,
              weeklyStudyHours / 20,
            ),
          ] else ...[
            // Desktop: All metrics in one row
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    'Average Score',
                    '${overallProgress.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    overallProgress / 100,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressMetric(
                    'Study Streak',
                    '$currentStreak days',
                    Icons.local_fire_department,
                    currentStreak / 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressMetric(
                    'Study Hours',
                    '${weeklyStudyHours}h this week',
                    Icons.access_time,
                    weeklyStudyHours / 20,
                  ),
                ),
              ],
            ),
          ],
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Exam countdown - Responsive layout
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: isSmallScreen 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD62828),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.event, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BECE 2026',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '$beceCountdownDays days remaining',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'re on track! 🎯',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD62828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.event, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BECE 2026',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$beceCountdownDays days remaining',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'You\'re on track! 🎯',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String title, String value, IconData icon, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildSubjectProgressCard() {
    // If no subject progress data, show default subjects with 0%
    final displayProgress = _subjectProgress.isEmpty 
        ? [
            SubjectProgress('RME', 0.0, Colors.blue),
            SubjectProgress('Trivia', 0.0, Colors.green),
          ]
        : _subjectProgress;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subject Progress',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              TextButton(
                onPressed: () => _showComingSoon('Detailed Analytics'),
                child: Text(
                  'View All',
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFD62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(displayProgress.map((subject) => _buildSubjectProgressItem(subject)).toList()),
        ],
      ),
    );
  }

  Widget _buildSubjectProgressItem(SubjectProgress subject) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subject.name,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${subject.progress.toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: subject.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: subject.progress / 100,
            backgroundColor: subject.color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(subject.color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          ..._activityItems.map((activity) => _buildActivityItem(
            activity['title'] as String,
            activity['time'] as String,
            activity['icon'] as IconData,
            activity['color'] as Color,
            activity['detail'] as String,
          )),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$detail • $time',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickStatItem('Questions Answered', questionsAnswered.toString(), Icons.quiz),
          _buildQuickStatItem(
            'Average Score', 
            '${(overallProgress * 0.85).toStringAsFixed(1)}%', 
            Icons.trending_up,
            showTrend: _recentActivity.length >= 3,
            trendValue: _calculateScoreTrend(),
          ),
          _buildQuickStatItem('Study Streak', '$currentStreak days', Icons.local_fire_department),
          const Divider(height: 24),
          _buildQuickStatItem('Past Questions Solved', pastQuestionsAnswered.toString(), Icons.history_edu),
          _buildQuickStatItem(
            'Past Questions Average Score', 
            '${pastQuestionsProgress.toStringAsFixed(1)}%', 
            Icons.school,
            showTrend: pastQuestionsAnswered > 5,
            trendValue: pastQuestionsProgress > 70 ? 1.0 : pastQuestionsProgress < 50 ? -1.0 : 0.0,
          ),
          const Divider(height: 24),
          _buildQuickStatItem('Trivia Answered', triviaQuestionsAnswered.toString(), Icons.emoji_events),
          _buildQuickStatItem(
            'Trivia Average Score', 
            '${triviaProgress.toStringAsFixed(1)}%', 
            Icons.stars,
            showTrend: triviaQuestionsAnswered > 5,
            trendValue: triviaProgress > 75 ? 1.0 : triviaProgress < 60 ? -1.0 : 0.0,
          ),
          const Divider(height: 24),
          // Advanced metrics
          _buildQuickStatItem('Weekly Study Hours', '${weeklyStudyHours}h', Icons.access_time),
          _buildQuickStatItem('XP Earned', _formatXP(userXP), Icons.flash_on),
          _buildQuickStatItem('Current Rank', currentRank?.name ?? 'Learner', Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon, {bool showTrend = false, double? trendValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFD62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          if (showTrend && trendValue != null) ...[
            const SizedBox(width: 8),
            Icon(
              trendValue > 0 ? Icons.trending_up : trendValue < 0 ? Icons.trending_down : Icons.trending_flat,
              size: 14,
              color: trendValue > 0 ? Colors.green : trendValue < 0 ? Colors.red : Colors.grey,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastQuestionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, color: Color(0xFF1A1E3F), size: 20),
              const SizedBox(width: 8),
              Text(
                'Past Questions Progress',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Past Questions Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1E3F),
                  const Color(0xFF1A1E3F).withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Questions Solved',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pastQuestionsAnswered.toString(),
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Average Score',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pastQuestionsProgress.toStringAsFixed(1)}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD62828),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pastQuestionsProgress / 100,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Trivia Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade600,
                  Colors.orange.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Trivia Challenge',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTriviaStatItem('Answered', triviaQuestionsAnswered.toString()),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _buildTriviaStatItem('Score', '${triviaProgress.toStringAsFixed(1)}%'),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _buildTriviaStatItem('Correct', triviaCorrect.toString()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriviaStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingDeadlines() {
    // Generate dynamic upcoming items based on user behavior
    _generateUpcomingItems();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          if (_upcomingItems.isEmpty) ...[
            _buildDeadlineItem('No upcoming items', 'Check back later', Colors.grey),
          ] else ...[
            ..._upcomingItems.map((item) => _buildSmartDeadlineItem(item)),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartDeadlineItem(Map<String, dynamic> item) {
    final title = item['title'] as String;
    final description = item['description'] as String;
    final type = item['type'] as String;
    final estimatedTime = item['estimatedTime'] as String;
    final difficulty = item['difficulty'] as String;
    final reward = item['reward'] as String;
    final priority = item['priority'] as String;

    // Color coding based on type and priority
    Color getItemColor() {
      if (priority == 'high') return Colors.red;
      if (type == 'exam_prep') return Colors.red;
      if (type == 'challenge') return Colors.orange;
      if (type == 'fun') return Colors.green;
      if (type == 'remedial') return Colors.blue;
      return Colors.purple;
    }

    final color = getItemColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    estimatedTime,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                description,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(difficulty).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      difficulty,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: _getDifficultyColor(difficulty),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reward: $reward',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
      case 'expert':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  void _generateUpcomingItems() {
    _upcomingItems = [];
    final userProfile = _userBehaviorProfile;
    final learningStyle = userProfile['learningStyle'] as String? ?? 'explorer';
    final engagementLevel = userProfile['engagementLevel'] as String? ?? 'needs_encouragement';
    final studyPatterns = userProfile['studyPatterns'] as Map<String, dynamic>? ?? {};
    final weakAreas = userProfile['weaknesses'] as List<String>? ?? [];
    final preferredSubjects = userProfile['preferredSubjects'] as List<String>? ?? [];

    // ML-powered upcoming content generation

    // 1. Adaptive difficulty progression
    if (overallProgress >= 80.0) {
      _upcomingItems.add({
        'title': 'Advanced Challenge Series',
        'description': 'Master complex problems in ${preferredSubjects.isNotEmpty ? preferredSubjects.first : 'your strongest subjects'}',
        'type': 'challenge',
        'priority': 'high',
        'estimatedTime': '45 min',
        'difficulty': 'Advanced',
        'reward': '200 XP',
      });
    } else if (overallProgress >= 60.0) {
      _upcomingItems.add({
        'title': 'Intermediate Mastery',
        'description': 'Build deeper understanding in ${weakAreas.isNotEmpty ? weakAreas.first : 'core subjects'}',
        'type': 'practice',
        'priority': 'high',
        'estimatedTime': '30 min',
        'difficulty': 'Intermediate',
        'reward': '150 XP',
      });
    } else {
      _upcomingItems.add({
        'title': 'Foundation Builder',
        'description': 'Strengthen basics in ${preferredSubjects.isNotEmpty ? preferredSubjects.first : 'key subjects'}',
        'type': 'foundation',
        'priority': 'high',
        'estimatedTime': '20 min',
        'difficulty': 'Beginner',
        'reward': '100 XP',
      });
    }

    // 2. Learning style-specific upcoming content
    switch (learningStyle) {
      case 'quick_learner':
        _upcomingItems.add({
          'title': 'Rapid Concept Review',
          'description': 'Quick mastery sessions for efficient learners',
          'type': 'review',
          'priority': 'medium',
          'estimatedTime': '15 min',
          'difficulty': 'Adaptive',
          'reward': '80 XP',
        });
        break;
      case 'consistent_builder':
        _upcomingItems.add({
          'title': 'Daily Progress Builder',
          'description': 'Structured daily learning path for steady improvement',
          'type': 'structured',
          'priority': 'medium',
          'estimatedTime': '25 min',
          'difficulty': 'Progressive',
          'reward': '120 XP',
        });
        break;
      case 'challenge_seeker':
        _upcomingItems.add({
          'title': 'Elite Problem Solving',
          'description': 'Complex challenges for advanced problem-solvers',
          'type': 'elite',
          'priority': 'medium',
          'estimatedTime': '50 min',
          'difficulty': 'Expert',
          'reward': '250 XP',
        });
        break;
    }

    // 3. Engagement-based motivation items
    switch (engagementLevel) {
      case 'highly_engaged':
        _upcomingItems.add({
          'title': 'Mentorship Opportunity',
          'description': 'Share your knowledge and help fellow students',
          'type': 'social',
          'priority': 'low',
          'estimatedTime': '60 min',
          'difficulty': 'Variable',
          'reward': '300 XP',
        });
        break;
      case 'moderately_engaged':
        _upcomingItems.add({
          'title': 'Achievement Milestone',
          'description': 'Reach your next learning milestone this week',
          'type': 'milestone',
          'priority': 'medium',
          'estimatedTime': 'Variable',
          'difficulty': 'Personal',
          'reward': 'Milestone Badge',
        });
        break;
      case 'needs_encouragement':
        _upcomingItems.add({
          'title': 'Quick Win Session',
          'description': 'Easy victories to build confidence and momentum',
          'type': 'motivation',
          'priority': 'high',
          'estimatedTime': '10 min',
          'difficulty': 'Easy',
          'reward': '50 XP + Confidence Boost',
        });
        break;
    }

    // 4. Subject-specific upcoming content
    if (weakAreas.isNotEmpty) {
      _upcomingItems.add({
        'title': '${weakAreas.first} Intensive',
        'description': 'Focused improvement in your weakest subject area',
        'type': 'remedial',
        'priority': 'high',
        'estimatedTime': '35 min',
        'difficulty': 'Targeted',
        'reward': '180 XP',
      });
    }

    // 5. Study pattern optimization
    final frequency = studyPatterns['frequency'] as String? ?? 'low';
    if (frequency == 'high') {
      _upcomingItems.add({
        'title': 'Quality Deep Dive',
        'description': 'In-depth exploration of complex topics',
        'type': 'deep_learning',
        'priority': 'medium',
        'estimatedTime': '40 min',
        'difficulty': 'Advanced',
        'reward': '220 XP',
      });
    } else {
      _upcomingItems.add({
        'title': 'Efficient Learning Sprint',
        'description': 'Maximize learning impact in shorter sessions',
        'type': 'sprint',
        'priority': 'medium',
        'estimatedTime': '20 min',
        'difficulty': 'Focused',
        'reward': '110 XP',
      });
    }

    // 6. Rank progression challenges
    if (nextRank != null) {
      final xpToNext = nextRank!.minXP - userXP;
      if (xpToNext <= 1000) {
        _upcomingItems.add({
          'title': 'Rank Advancement Quest',
          'description': 'Special challenges to reach ${nextRank!.name} rank',
          'type': 'rank_quest',
          'priority': 'high',
          'estimatedTime': '45 min',
          'difficulty': 'Challenging',
          'reward': '${nextRank!.name} Rank + ${xpToNext} XP',
        });
      }
    }

    // 7. Seasonal/temporal content
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final hour = now.hour;

    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      _upcomingItems.add({
        'title': 'Weekend Deep Study',
        'description': 'Extended learning session for comprehensive understanding',
        'type': 'weekend',
        'priority': 'medium',
        'estimatedTime': '60 min',
        'difficulty': 'Comprehensive',
        'reward': '300 XP',
      });
    }

    if (hour >= 6 && hour < 12) {
      _upcomingItems.add({
        'title': 'Morning Mastery',
        'description': 'Prime time for focused learning and retention',
        'type': 'morning',
        'priority': 'low',
        'estimatedTime': '30 min',
        'difficulty': 'Optimal',
        'reward': '150 XP',
      });
    }

    // 8. Trivia and fun learning
    if (triviaQuestionsAnswered < 10) {
      _upcomingItems.add({
        'title': 'Fun Trivia Challenge',
        'description': 'Enjoyable way to build general knowledge',
        'type': 'fun',
        'priority': 'low',
        'estimatedTime': '15 min',
        'difficulty': 'Fun',
        'reward': '75 XP + Fun Badge',
      });
    }

    // 9. Past questions preparation
    if (pastQuestionsAnswered < 20 && questionsAnswered >= 15) {
      _upcomingItems.add({
        'title': 'BECE Exam Practice',
        'description': 'Essential preparation for BECE success',
        'type': 'exam_prep',
        'priority': 'high',
        'estimatedTime': '40 min',
        'difficulty': 'Exam Level',
        'reward': '200 XP',
      });
    }

    // 10. Interdisciplinary learning
    if (_subjectProgress.length >= 3) {
      _upcomingItems.add({
        'title': 'Knowledge Integration',
        'description': 'Connect concepts across different subjects',
        'type': 'interdisciplinary',
        'priority': 'medium',
        'estimatedTime': '35 min',
        'difficulty': 'Advanced',
        'reward': '190 XP',
      });
    }

    // Sort by priority and relevance
    _upcomingItems.sort((a, b) {
      final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
      final aPriority = priorityOrder[a['priority'] as String] ?? 1;
      final bPriority = priorityOrder[b['priority'] as String] ?? 1;

      if (aPriority != bPriority) {
        return bPriority.compareTo(aPriority);
      }

      // Secondary sort by estimated time (prefer shorter sessions for engagement)
      final aTime = _parseTime(a['estimatedTime'] as String);
      final bTime = _parseTime(b['estimatedTime'] as String);
      return aTime.compareTo(bTime);
    });

    // Limit to 4 items for optimal UX
    if (_upcomingItems.length > 4) {
      _upcomingItems = _upcomingItems.sublist(0, 4);
    }
  }

  int _parseTime(String timeStr) {
    if (timeStr == 'Variable') return 30; // Default 30 min
    final match = RegExp(r'(\d+)').firstMatch(timeStr);
    return match != null ? int.parse(match.group(1)!) : 30;
  }

  Widget _buildDeadlineItem(String title, String timeLeft, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            timeLeft,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton('Continue Study', Icons.play_arrow, () => setState(() => _selectedIndex = 1)),
          const SizedBox(height: 8),
          _buildQuickActionButton('Take Quiz', Icons.quiz, () => setState(() => _selectedIndex = 1)),
          const SizedBox(height: 8),
          _buildQuickActionButton('Read Books', Icons.menu_book, () => setState(() => _selectedIndex = 2)),
          const SizedBox(height: 8),
          // Quick action to take an RME quiz (navigates to question collections filtered to RME)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuestionCollectionsPage(initialSubject: 'RME'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.book, size: 16, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 12),
                  Text(
                    'Take RME Quiz',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFD62828)),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAchievements() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Achievements',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _userAchievements.map((achievement) => _buildAchievementBadge(
                achievement['title'] as String,
                achievement['icon'] as IconData,
                achievement['color'] as Color,
                description: achievement['description'] as String?,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(String title, IconData icon, Color color, {String? description}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD62828), Color(0xFFE94560)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62828).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Study Recommendations',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Based on your recent performance, here are some personalized recommendations:',
            style: GoogleFonts.montserrat(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          ..._studyRecommendations.map((recommendation) => _buildRecommendationItem(recommendation)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _selectedIndex = 4),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD62828),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Start Learning',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Smart Insights',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'AI-powered insights based on your learning patterns:',
            style: GoogleFonts.montserrat(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          ..._personalizedContent.map((insight) => _buildInsightItem(insight)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These insights adapt as you learn more',
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: GoogleFonts.montserrat(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Page implementations for other tabs
  Widget _buildQuestionsPage() {
    return const QuestionCollectionsPage();
  }

Widget _buildTextbooksPage() {
  // Return the existing TextbooksPage with tabs (All Books, Textbooks, Storybooks)
  return const TextbooksPage();
}  Widget _buildFeedbackPage() {
    return const FeedbackPage();
  }

  Widget _buildTriviaPage() {
    return const TriviaCategoriesPage();
  }

  // Helper methods
  void _showMobileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Leaderboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatXP(int xp) {
    if (xp >= 1000000) {
      return '${(xp / 1000000).toStringAsFixed(1)}M';
    } else if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}K';
    }
    return xp.toString();
  }

  void _showRankDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.01),
      barrierDismissible: true,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;
        
        return Stack(
          children: [
            // Invisible barrier to close on outside click
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            // Positioned dropdown below rank badge - Apple style
            Positioned(
              top: isMobile ? 56 : 64,
              right: isMobile ? 44 : 60,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    alignment: Alignment.topRight,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Material(
                  elevation: 0,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Current Rank - Compact
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              '${currentRank?.name.toUpperCase() ?? 'LEARNER'} · ${_formatXP(userXP)}XP',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          
                          // Subtle divider
                          Container(
                            height: 0.5,
                            color: Colors.grey.shade200,
                          ),
                          
                          // All Ranks Button - Minimal
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RedesignedAllRanksPage(userXP: userXP),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.emoji_events_outlined,
                                    size: 16,
                                    color: currentRank?.getTierColor() ?? Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'All Ranks',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: currentRank?.getTierColor() ?? Colors.grey.shade600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProfileMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth * 0.18; // 50% reduction from typical 36% to 18%
        
        return Stack(
          children: [
            // Invisible barrier to close on outside click
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            // Positioned dialog in top right
            Positioned(
              top: 70, // Below header (header height ~60px + spacing)
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: dialogWidth.clamp(280, 350), // Min 280, max 350
                  constraints: const BoxConstraints(maxHeight: 600),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User Profile Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF1A1E3F),
                                backgroundImage: _getAvatarImage(),
                                child: _getAvatarImage() == null ? Text(
                                  userName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userClass,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Menu Items
                        _buildProfileMenuItem(Icons.person, 'Profile Settings', () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedIndex = 0; // Navigate to Profile tab
                            _showingProfile = true;
                          });
                        }),
                        
                        const Divider(height: 1),
                        
                        // Footer Pages Section
                        _buildProfileMenuItem(Icons.attach_money_outlined, 'Pricing', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/pricing');
                        }),
                        _buildProfileMenuItem(Icons.payment, 'Payment', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/payment');
                        }),
                        _buildProfileMenuItem(Icons.info_outline, 'About Us', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/about');
                        }),
                        _buildProfileMenuItem(Icons.phone_outlined, 'Contact', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/contact');
                        }),
                        _buildProfileMenuItem(Icons.help_outline, 'FAQ', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/faq');
                        }),
                        _buildProfileMenuItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/privacy');
                        }),
                        _buildProfileMenuItem(Icons.gavel_outlined, 'Terms of Service', () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/terms');
                        }),
                        
                        const Divider(height: 1),
                        
                        // Sign Out
                        _buildProfileMenuItem(
                          Icons.logout,
                          'Sign Out',
                          _handleSignOut,
                          color: const Color(0xFFD62828),
                        ),
                        
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: color ?? Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: const Color(0xFF1A1E3F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Clear navigation stack and go to landing page
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
  }
}

// Data model for subject progress
class SubjectProgress {
  final String name;
  final double progress;
  final Color color;

  SubjectProgress(this.name, this.progress, this.color);
}
