import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _isDarkMode = false;
  
  // User progress data (would come from Firestore in real app)
  String userName = "Alex";
  double overallProgress = 76.5;
  int currentStreak = 12;
  int weeklyStudyHours = 8;
  int questionsAnswered = 147;
  int upcomingExamDays = 45;
  
  // Subject progress data
  final List<SubjectProgress> _subjectProgress = [
    SubjectProgress('Mathematics', 85.0, Colors.blue),
    SubjectProgress('English', 72.0, Colors.green),
    SubjectProgress('Science', 68.0, Colors.orange),
    SubjectProgress('Social Studies', 90.0, Colors.purple),
    SubjectProgress('ICT', 78.0, Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 6, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    
    _loadUserData();
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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            userName = data['firstName'] ?? user.displayName?.split(' ').first ?? 'Student';
          });
        }
      } catch (e) {
        // Handle error silently or show user-friendly message
        print('Error loading user data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF8FAFE),
          body: SafeArea(
            child: Row(
              children: [
                // Sidebar Navigation (Desktop)
                if (!isSmallScreen) _buildSideNavigation(),
                
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(context),
                      
                      // Content Area
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: [
                            _buildDashboard(),
                            _buildQuestionsPage(),
                            _buildTextbooksPage(),
                            _buildMockExamsPage(),
                            _buildTriviaPage(),
                            _buildAITutorPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Navigation (Mobile)
          bottomNavigationBar: isSmallScreen ? _buildBottomNavigation() : null,
        );
      },
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Uriel Academy',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
          ),
          
          // User Profile Card
          Container(
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
                          color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
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
          
          const SizedBox(height: 24),
          
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                  _buildNavItem(1, Icons.quiz_outlined, Icons.quiz, 'Questions'),
                  _buildNavItem(2, Icons.menu_book_outlined, Icons.menu_book, 'Textbooks'),
                  _buildNavItem(3, Icons.assessment_outlined, Icons.assessment, 'Mock Exams'),
                  _buildNavItem(4, Icons.psychology_outlined, Icons.psychology, 'Trivia'),
                  _buildNavItem(5, Icons.smart_toy_outlined, Icons.smart_toy, 'AI Tutor'),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(),
                  ),
                  
                  _buildNavItem(-1, Icons.analytics_outlined, Icons.analytics, 'Analytics'),
                  _buildNavItem(-2, Icons.leaderboard_outlined, Icons.leaderboard, 'Leaderboard'),
                  _buildNavItem(-3, Icons.group_outlined, Icons.group, 'Study Groups'),
                  _buildNavItem(-4, Icons.folder_outlined, Icons.folder, 'Resources'),
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
                  leading: Icon(
                    _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.grey[600],
                  ),
                  title: Text(
                    _isDarkMode ? 'Light Mode' : 'Dark Mode',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Switch(
                    value: _isDarkMode,
                    onChanged: (value) => setState(() => _isDarkMode = value),
                    activeColor: const Color(0xFFD62828),
                  ),
                ),
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

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon, String title) {
    final isSelected = _selectedIndex == index;
    final isMainNav = index >= 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(
          isSelected ? filledIcon : outlinedIcon,
          color: isSelected 
              ? const Color(0xFFD62828)
              : (_isDarkMode ? Colors.grey[400] : Colors.grey[600]),
        ),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
                ? const Color(0xFFD62828)
                : (_isDarkMode ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFFD62828).withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: isMainNav ? () => setState(() => _selectedIndex = index) : () => _showComingSoon(title),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFD62828),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Questions'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Books'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Mock'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Trivia'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI Tutor'),
        ],
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
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
                color: (_isDarkMode ? Colors.grey[800] : Colors.grey[100]),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
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
                  'Welcome back, $userName! 👋',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to continue your learning journey?',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Progress Overview Hero Card
          _buildProgressOverviewCard(),
          
          const SizedBox(height: 24),
          
          // Performance Metrics & Subject Progress
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
          
          const SizedBox(height: 24),
          
          // Recent Achievements
          _buildRecentAchievements(),
          
          const SizedBox(height: 24),
          
          // AI Recommendations
          _buildAIRecommendations(),
        ],
      ),
    );
  }

  Widget _buildProgressOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1E3F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
          
          const SizedBox(height: 24),
          
          // Progress metrics row
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
          
          const SizedBox(height: 20),
          
          // Exam countdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
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
                      'BECE 2025',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$upcomingExamDays days remaining',
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
                  color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
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
          ...(_subjectProgress.map((subject) => _buildSubjectProgressItem(subject)).toList()),
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
                  color: _isDarkMode ? Colors.white : Colors.black87,
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
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
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
                    color: _isDarkMode ? Colors.white : Colors.black87,
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
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickStatItem('Questions Answered', questionsAnswered.toString(), Icons.quiz),
          _buildQuickStatItem('Average Score', '${(overallProgress * 0.85).toStringAsFixed(1)}%', Icons.trending_up),
          _buildQuickStatItem('Study Streak', '$currentStreak days', Icons.local_fire_department),
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingDeadlines() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          _buildDeadlineItem('BECE 2025', '$upcomingExamDays days', Colors.red),
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
                color: _isDarkMode ? Colors.white : Colors.black87,
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
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton('Continue Study', Icons.play_arrow, () => setState(() => _selectedIndex = 1)),
          const SizedBox(height: 8),
          _buildQuickActionButton('Take Quiz', Icons.quiz, () => setState(() => _selectedIndex = 1)),
          const SizedBox(height: 8),
          _buildQuickActionButton('Ask AI Tutor', Icons.smart_toy, () => setState(() => _selectedIndex = 5)),
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
                color: _isDarkMode ? Colors.white : Colors.black87,
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
        color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
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
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
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
              color: _isDarkMode ? Colors.white : Colors.black87,
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
              Icon(Icons.smart_toy, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'AI Tutor Recommendations',
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
            onPressed: () => setState(() => _selectedIndex = 5),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD62828),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Chat with AI Tutor',
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
    return _buildFeaturePage(
      'Past Questions',
      'Access comprehensive past questions for BECE and WASSCE',
      Icons.quiz_outlined,
      [
        _buildFeatureCard('BECE Questions', 'Basic Education Certificate Exam', Icons.school, () => _showComingSoon('BECE Questions')),
        _buildFeatureCard('WASSCE Questions', 'West African Senior School Certificate', Icons.workspace_premium, () => _showComingSoon('WASSCE Questions')),
        _buildFeatureCard('Mock Tests', 'Practice with timed examinations', Icons.timer, () => _showComingSoon('Mock Tests')),
      ],
    );
  }

  Widget _buildTextbooksPage() {
    return _buildFeaturePage(
      'Digital Textbooks',
      'NACCA approved textbooks for all subjects',
      Icons.menu_book_outlined,
      [
        _buildFeatureCard('JHS Textbooks', 'Junior High School curriculum', Icons.school, () => _showComingSoon('JHS Textbooks')),
        _buildFeatureCard('SHS Textbooks', 'Senior High School curriculum', Icons.library_books, () => _showComingSoon('SHS Textbooks')),
        _buildFeatureCard('Reference Materials', 'Additional learning resources', Icons.folder_open, () => _showComingSoon('Reference Materials')),
      ],
    );
  }

  Widget _buildMockExamsPage() {
    return _buildFeaturePage(
      'Mock Examinations',
      'Full-length practice examinations with detailed feedback',
      Icons.assessment_outlined,
      [
        _buildFeatureCard('BECE Mock', 'Basic Education Certificate Mock', Icons.edit_note, () => _showComingSoon('BECE Mock')),
        _buildFeatureCard('WASSCE Mock', 'Senior School Certificate Mock', Icons.assignment, () => _showComingSoon('WASSCE Mock')),
        _buildFeatureCard('Custom Tests', 'Create your own practice tests', Icons.create, () => _showComingSoon('Custom Tests')),
      ],
    );
  }

  Widget _buildTriviaPage() {
    return _buildFeaturePage(
      'Learning Trivia',
      'Gamified learning with fun trivia challenges',
      Icons.psychology_outlined,
      [
        _buildFeatureCard('Daily Challenge', 'New questions every day', Icons.today, () => _showComingSoon('Daily Challenge')),
        _buildFeatureCard('Subject Trivia', 'Focus on specific subjects', Icons.category, () => _showComingSoon('Subject Trivia')),
        _buildFeatureCard('Multiplayer', 'Challenge your classmates', Icons.groups, () => _showComingSoon('Multiplayer')),
      ],
    );
  }

  Widget _buildAITutorPage() {
    return _buildFeaturePage(
      'AI Tutor Assistant',
      'Get personalized help and explanations from our AI tutor',
      Icons.smart_toy_outlined,
      [
        _buildFeatureCard('Ask Questions', 'Get instant answers to your questions', Icons.help_outline, () => _showComingSoon('AI Chat')),
        _buildFeatureCard('Study Plan', 'AI-generated personalized study plans', Icons.calendar_today, () => _showComingSoon('Study Plan')),
        _buildFeatureCard('Performance Analysis', 'Detailed insights into your learning', Icons.analytics, () => _showComingSoon('Performance Analysis')),
      ],
    );
  }

  Widget _buildFeaturePage(String title, String subtitle, IconData icon, List<Widget> features) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFD62828), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...features,
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String description, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E3F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1A1E3F), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
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
              leading: const Icon(Icons.notifications),
              title: const Text('Notification Settings'),
              onTap: () => _showComingSoon('Notification Settings'),
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () => _showComingSoon('Help & Support'),
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
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error signing out. Please try again.')),
      );
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