import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_styles.dart';
import '../services/connection_service.dart';
import '../services/auth_service.dart';
import 'question_collections_page.dart';
import 'textbooks_page.dart';
import 'mock_exams_page.dart';
import 'trivia_categories_page.dart';
import 'student_profile_page.dart';

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
  double overallProgress = 0.0; // Calculated from quiz results
  int currentStreak = 0; // Days of consecutive activity
  int weeklyStudyHours = 0; // Calculated from session time
  int questionsAnswered = 0; // Total questions from quizzes
  int beceCountdownDays = 0; // Live countdown to BECE 2026
  
  // Past Questions tracking
  int pastQuestionsAnswered = 0;
  double pastQuestionsProgress = 0.0;
  
  // Trivia tracking
  int triviaQuestionsAnswered = 0;
  double triviaProgress = 0.0;
  int triviaCorrect = 0;
  
  // Subject progress data - Live from quiz performance
  List<SubjectProgress> _subjectProgress = [];
  
  // Recent activity data
  List<Map<String, dynamic>> _recentActivity = [];

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
          });
        } else {
          setState(() {
            userName = user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
          });
        }
      } catch (e) {
        // Handle offline or connection errors gracefully
        setState(() {
          userName = user.displayName?.split(' ').first ?? _getNameFromEmail(user.email);
        });
        
        // Only log the error, don't show it to the user
        print('Unable to load user data (offline or connection issue): $e');
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
            print('Error parsing timestamp: $e');
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
      
    } catch (e) {
      print('Error loading user stats: $e');
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
    
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back to landing/login page
        // Show exit confirmation dialog instead
        return await showDialog<bool>(
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
                                      _buildMockExamsPage(),
                                      _buildTriviaPage(),
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
                                            _buildMockExamsPage(),
                                            _buildTriviaPage(),
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
            color: Colors.black.withOpacity(0.05),
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
          
          // Search Icon for mobile
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: Colors.grey[600]),
              onPressed: () => _showMobileSearch(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Notifications
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, color: Color(0xFFD62828), size: 20),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD62828),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => _showNotifications(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Profile Avatar
          GestureDetector(
            onTap: () => _showProfileMenu(),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1A1E3F),
              child: Text(
                userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
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
            color: Colors.black.withOpacity(0.05),
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
                color: const Color(0xFF1A1E3F).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1A1E3F).withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1A1E3F),
                    child: Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
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
                          'JHS Form 3 Student',
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
                  _buildNavItem(2, 'Textbooks'),
                  _buildNavItem(3, 'Mock Exams'),
                  _buildNavItem(4, 'Trivia'),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(),
                  ),
                  
                  _buildNavItem(-1, 'Analytics'),
                  _buildNavItem(-2, 'Leaderboard'),
                  _buildNavItem(-3, 'Study Groups'),
                  _buildNavItem(-4, 'Resources'),
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
        selectedTileColor: const Color(0xFFD62828).withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: isMainNav ? () => setState(() {
          _selectedIndex = index;
          _showingProfile = false; // Close profile when switching tabs
        }) : () => _showComingSoon(title),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final tabs = ['Dashboard', 'Questions', 'Books', 'Mock', 'Trivia'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedIndex == index;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedIndex = index;
              _showingProfile = false; // Close profile when switching tabs
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFD62828).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[index],
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? const Color(0xFFD62828)
                      : Colors.grey[600],
                ),
              ),
            ),
          );
        }),
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
            color: Colors.black.withOpacity(0.05),
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
          
          // Search Bar
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search questions, textbooks, topics...',
                  hintStyle: GoogleFonts.montserrat(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Notifications
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, color: Color(0xFFD62828)),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD62828),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => _showNotifications(),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Profile Avatar
          GestureDetector(
            onTap: () => _showProfileMenu(),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1A1E3F),
              child: Text(
                userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
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
                Text(
                  'Welcome $userName!',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isSmallScreen ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to continue your learning journey?',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          // Progress Overview Hero Card
          _buildProgressOverviewCard(),
          
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
            color: const Color(0xFF1A1E3F).withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.2),
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
                    'Overall Completion',
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
                    'Overall Completion',
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
          backgroundColor: Colors.white.withOpacity(0.3),
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
            color: Colors.black.withOpacity(0.05),
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
            backgroundColor: subject.color.withOpacity(0.2),
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
            color: Colors.black.withOpacity(0.05),
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
          _buildActivityItem(
            'Completed Mathematics Quiz',
            '2 hours ago',
            Icons.quiz,
            const Color(0xFF4CAF50),
            '8/10 correct',
          ),
          _buildActivityItem(
            'Read Science Chapter 5',
            '1 day ago',
            Icons.menu_book,
            const Color(0xFF2196F3),
            'Photosynthesis',
          ),
          _buildActivityItem(
            'Trivia Challenge',
            '2 days ago',
            Icons.psychology,
            const Color(0xFFE91E63),
            '850 points earned',
          ),
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
              color: color.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.05),
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
          _buildQuickStatItem('Average Score', '${(overallProgress * 0.85).toStringAsFixed(1)}%', Icons.trending_up),
          _buildQuickStatItem('Study Streak', '$currentStreak days', Icons.local_fire_department),
          const Divider(height: 24),
          _buildQuickStatItem('Past Questions Solved', pastQuestionsAnswered.toString(), Icons.history_edu),
          _buildQuickStatItem('Past Questions Score', '${pastQuestionsProgress.toStringAsFixed(1)}%', Icons.school),
          const Divider(height: 24),
          _buildQuickStatItem('Trivia Answered', triviaQuestionsAnswered.toString(), Icons.emoji_events),
          _buildQuickStatItem('Trivia Score', '${triviaProgress.toStringAsFixed(1)}%', Icons.stars),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon) {
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
            color: Colors.black.withOpacity(0.05),
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
              Icon(Icons.history_edu, color: const Color(0xFF1A1E3F), size: 20),
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
                  const Color(0xFF1A1E3F).withOpacity(0.8),
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
                    Icon(Icons.emoji_events, color: Colors.white, size: 20),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
          _buildDeadlineItem('BECE 2026', '$beceCountdownDays days', Colors.red),
          _buildDeadlineItem('Math Quiz', '3 days', Colors.orange),
          _buildDeadlineItem('Science Assignment', '1 week', Colors.blue),
        ],
      ),
    );
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
            color: Colors.black.withOpacity(0.05),
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
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
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
            color: Colors.black.withOpacity(0.05),
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
              children: [
                _buildAchievementBadge('7-Day Streak', Icons.local_fire_department, Colors.orange),
                _buildAchievementBadge('Quiz Master', Icons.quiz, Colors.blue),
                _buildAchievementBadge('Bookworm', Icons.menu_book, Colors.green),
                _buildAchievementBadge('Perfect Score', Icons.star, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
            color: const Color(0xFFD62828).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          _buildRecommendationItem('Focus on Algebra practice - detected weak areas in equations'),
          _buildRecommendationItem('Review Cell Biology chapter for upcoming Science test'),
          _buildRecommendationItem('Great progress in English! Keep up the reading streak'),
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
                color: Colors.white.withOpacity(0.9),
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
    return const TextbooksPage();
  }

  Widget _buildMockExamsPage() {
    return const MockExamsPage();
  }

  Widget _buildTriviaPage() {
    return const TriviaCategoriesPage();
  }

  // Helper methods
  void _showMobileSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Search',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Search questions, textbooks, topics...',
            hintStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon('Search');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text('Search', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

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

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.2),
                child: const Icon(Icons.quiz, color: Colors.blue),
              ),
              title: const Text('New Math Quiz Available'),
              subtitle: const Text('2 hours ago'),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: const Icon(Icons.star, color: Colors.green),
              ),
              title: const Text('Achievement Unlocked!'),
              subtitle: const Text('7-Day Study Streak'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1A1E3F),
                child: Text(userName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(userName),
              subtitle: const Text('JHS Form 3 Student'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile Settings'),
              onTap: () => _showComingSoon('Profile Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Uriel Academy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/about');
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/privacy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Terms of Service'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/terms');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notification Settings'),
              onTap: () => _showComingSoon('Notification Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/contact');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFD62828)),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFFD62828))),
              onTap: _handleSignOut,
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
