import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';

class SchoolDashboardPage extends StatefulWidget {
  const SchoolDashboardPage({super.key});

  @override
  State<SchoolDashboardPage> createState() => _SchoolDashboardPageState();
}

class _SchoolDashboardPageState extends State<SchoolDashboardPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  
  int _selectedNavIndex = 0;
  final String _userRole = 'Principal'; // Principal, Teacher
  final String _schoolName = 'Presbyterian Boys\' Secondary School';
  
  final List<Map<String, dynamic>> _navigationItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'key': 'dashboard'},
    {'icon': Icons.people_rounded, 'label': 'Students', 'key': 'students'},
    {'icon': Icons.analytics_rounded, 'label': 'Performance', 'key': 'performance'},
    {'icon': Icons.library_books_rounded, 'label': 'Content', 'key': 'content'},
    {'icon': Icons.chat_rounded, 'label': 'Communication', 'key': 'communication'},
    {'icon': Icons.account_balance_wallet_rounded, 'label': 'Finance', 'key': 'finance'},
    {'icon': Icons.emoji_events_rounded, 'label': 'Leaderboards', 'key': 'leaderboards'},
    {'icon': Icons.security_rounded, 'label': 'Security', 'key': 'security'},
    {'icon': Icons.settings_rounded, 'label': 'Settings', 'key': 'settings'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scrollController = ScrollController();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final isMediumScreen = screenWidth < 1024;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: Row(
        children: [
          // Side Navigation (Desktop & Tablet)
          if (!isSmallScreen) _buildSideNavigation(isMediumScreen),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Header
                _buildTopHeader(isSmallScreen),
                
                // Main Dashboard Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildMainContent(isSmallScreen, isMediumScreen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom Navigation (Mobile)
      bottomNavigationBar: isSmallScreen ? _buildBottomNavigation() : null,
    );
  }

  Widget _buildSideNavigation(bool isMediumScreen) {
    return Container(
      width: isMediumScreen ? 200 : 240,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1E3F),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Uriel Academy',
                  style: AppStyles.brandNameDark(fontSize: isMediumScreen ? 16 : 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'School Dashboard',
                  style: GoogleFonts.montserrat(
                    fontSize: isMediumScreen ? 12 : 14,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white24),
          
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedNavIndex == index;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedNavIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? const Color(0xFFD62828).withOpacity(0.2)
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item['icon'],
                              color: isSelected 
                                ? const Color(0xFFD62828) 
                                : Colors.white.withOpacity(0.8),
                              size: isMediumScreen ? 20 : 22,
                            ),
                            const SizedBox(width: 12),
                            if (!isMediumScreen) Expanded(
                              child: Text(
                                item['label'],
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: isSelected 
                                    ? const Color(0xFFD62828) 
                                    : Colors.white.withOpacity(0.9),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // User Info
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: isMediumScreen ? 20 : 24,
                  backgroundColor: const Color(0xFFD62828),
                  child: Text(
                    _userRole[0],
                    style: GoogleFonts.montserrat(
                      fontSize: isMediumScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isMediumScreen) ...[
                  const SizedBox(height: 8),
                  Text(
                    _userRole,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _schoolName,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mobile Menu Button
          if (isSmallScreen) ...[
            IconButton(
              onPressed: () => _showMobileMenu(context),
              icon: const Icon(Icons.menu, color: Color(0xFF1A1E3F)),
            ),
            const SizedBox(width: 12),
          ],
          
          // Page Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getPageTitle(),
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                if (!isSmallScreen) Text(
                  _schoolName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Header Actions
          Row(
            children: [
              // Global Search
              if (!isSmallScreen) ...[
                Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      hintStyle: GoogleFonts.montserrat(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              
              // Notifications
              Stack(
                children: [
                  IconButton(
                    onPressed: () => _showNotifications(context),
                    icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A1E3F)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
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
              
              // Profile Menu
              PopupMenuButton<String>(
                onSelected: (value) => _handleProfileAction(value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20),
                        const SizedBox(width: 12),
                        Text('Profile', style: GoogleFonts.montserrat()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text('Settings', style: GoogleFonts.montserrat()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text('Logout', style: GoogleFonts.montserrat()),
                      ],
                    ),
                  ),
                ],
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1A1E3F),
                  child: Text(
                    _userRole[0],
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen, bool isMediumScreen) {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardContent(isSmallScreen, isMediumScreen);
      case 1:
        return _buildStudentManagement(isSmallScreen, isMediumScreen);
      case 2:
        return _buildPerformanceReports(isSmallScreen, isMediumScreen);
      case 3:
        return _buildContentManagement(isSmallScreen, isMediumScreen);
      case 4:
        return _buildCommunication(isSmallScreen, isMediumScreen);
      case 5:
        return _buildFinanceModule(isSmallScreen, isMediumScreen);
      case 6:
        return _buildLeaderboards(isSmallScreen, isMediumScreen);
      case 7:
        return _buildSecurityModule(isSmallScreen, isMediumScreen);
      case 8:
        return _buildSettingsModule(isSmallScreen, isMediumScreen);
      default:
        return _buildDashboardContent(isSmallScreen, isMediumScreen);
    }
  }

  Widget _buildDashboardContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats Row
          _buildQuickStatsRow(isSmallScreen, isMediumScreen),
          
          const SizedBox(height: 24),
          
          // Main Dashboard Widgets
          if (isSmallScreen) ...[
            _buildSchoolProgressWidget(isSmallScreen),
            const SizedBox(height: 20),
            _buildTopStudentsWidget(isSmallScreen),
            const SizedBox(height: 20),
            _buildRecentActivityWidget(isSmallScreen),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSchoolProgressWidget(isSmallScreen),
                      const SizedBox(height: 20),
                      _buildRecentActivityWidget(isSmallScreen),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildTopStudentsWidget(isSmallScreen),
                      const SizedBox(height: 20),
                      _buildQuickActionsWidget(isSmallScreen),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(bool isSmallScreen, bool isMediumScreen) {
    final stats = [
      {
        'title': 'Total Students',
        'value': '1,247',
        'change': '+12%',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF4CAF50),
      },
      {
        'title': 'Active Subscriptions',
        'value': '892',
        'change': '71.5%',
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF2196F3),
      },
      {
        'title': 'Average Performance',
        'value': '78.5%',
        'change': '+5.2%',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFFF9800),
      },
      {
        'title': 'Commission Earned',
        'value': 'GHS 15,420',
        'change': '+8.7%',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFFD62828),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 2 : (isMediumScreen ? 2 : 4),
        childAspectRatio: isSmallScreen ? 1.5 : 2.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(stat, isSmallScreen);
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stat['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  stat['icon'],
                  color: stat['color'],
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stat['change'],
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            stat['value'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            stat['title'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolProgressWidget(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Subject Performance Overview',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Text(
                'This Term',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Subject performance bars
          ...['Mathematics', 'English', 'Science', 'Social Studies', 'ICT'].map((subject) {
            final scores = {
              'Mathematics': 85.2,
              'English': 78.9,
              'Science': 82.1,
              'Social Studies': 76.5,
              'ICT': 88.7,
            };
            return _buildSubjectProgressBar(subject, scores[subject]!, isSmallScreen);
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectProgressBar(String subject, double score, bool isSmallScreen) {
    Color getScoreColor(double score) {
      if (score >= 80) return const Color(0xFF4CAF50);
      if (score >= 70) return const Color(0xFFFF9800);
      return const Color(0xFFD62828);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subject,
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: getScoreColor(score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(getScoreColor(score)),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildTopStudentsWidget(bool isSmallScreen) {
    final topStudents = [
      {'name': 'Kwame Asante', 'class': 'SHS 3A', 'score': 94.5, 'streak': 12},
      {'name': 'Ama Osei', 'class': 'SHS 3B', 'score': 92.8, 'streak': 8},
      {'name': 'Kofi Mensah', 'class': 'SHS 2A', 'score': 91.2, 'streak': 15},
      {'name': 'Akosua Boateng', 'class': 'SHS 3A', 'score': 89.7, 'streak': 6},
      {'name': 'Yaw Oppong', 'class': 'SHS 2B', 'score': 88.9, 'streak': 9},
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Top Performers',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.emoji_events_rounded,
                color: const Color(0xFFD62828),
                size: isSmallScreen ? 20 : 24,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...topStudents.asMap().entries.map((entry) {
            final index = entry.key;
            final student = entry.value;
            return _buildStudentRankItem(student, index + 1, isSmallScreen);
          }),
        ],
      ),
    );
  }

  Widget _buildStudentRankItem(Map<String, dynamic> student, int rank, bool isSmallScreen) {
    Color getRankColor(int rank) {
      switch (rank) {
        case 1: return const Color(0xFFFFD700);
        case 2: return const Color(0xFFC0C0C0);
        case 3: return const Color(0xFFCD7F32);
        default: return Colors.grey[400]!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: getRankColor(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'],
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                Text(
                  student['class'],
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${student['score']}%',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF9800),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${student['streak']}',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: const Color(0xFFFF9800),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityWidget(bool isSmallScreen) {
    final activities = [
      {'type': 'new_student', 'message': 'Kwame Asante joined SHS 3A', 'time': '2 min ago', 'icon': Icons.person_add_rounded},
      {'type': 'achievement', 'message': 'Ama Osei completed Math mock exam (95%)', 'time': '15 min ago', 'icon': Icons.emoji_events_rounded},
      {'type': 'alert', 'message': '12 students need attention in English', 'time': '1 hour ago', 'icon': Icons.warning_rounded},
      {'type': 'payment', 'message': 'New subscription payment received', 'time': '2 hours ago', 'icon': Icons.payment_rounded},
      {'type': 'system', 'message': 'Weekly reports generated successfully', 'time': '3 hours ago', 'icon': Icons.assessment_rounded},
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: const Color(0xFFD62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...activities.map((activity) => _buildActivityItem(activity, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isSmallScreen) {
    Color getActivityColor(String type) {
      switch (type) {
        case 'new_student': return const Color(0xFF4CAF50);
        case 'achievement': return const Color(0xFFFFD700);
        case 'alert': return const Color(0xFFFF9800);
        case 'payment': return const Color(0xFF2196F3);
        case 'system': return Colors.grey[600]!;
        default: return Colors.grey[600]!;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: getActivityColor(activity['type']).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity['icon'],
              color: getActivityColor(activity['type']),
              size: 16,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['message'],
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                Text(
                  activity['time'],
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
    );
  }

  Widget _buildQuickActionsWidget(bool isSmallScreen) {
    final actions = [
      {'label': 'Add Student', 'icon': Icons.person_add_rounded, 'color': const Color(0xFF4CAF50)},
      {'label': 'Send Announcement', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF2196F3)},
      {'label': 'Generate Report', 'icon': Icons.assessment_rounded, 'color': const Color(0xFFFF9800)},
      {'label': 'View Commission', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFFD62828)},
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ...actions.map((action) => _buildQuickActionButton(action, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(Map<String, dynamic> action, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleQuickAction(action['label']),
        style: ElevatedButton.styleFrom(
          backgroundColor: action['color'].withOpacity(0.1),
          foregroundColor: action['color'],
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            Icon(action['icon'], size: 20),
            const SizedBox(width: 12),
            Text(
              action['label'],
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder widgets for other modules - to be implemented
  Widget _buildStudentManagement(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Student Management Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPerformanceReports(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Performance & Reports Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContentManagement(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Content & Resources Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCommunication(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Communication Tools Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFinanceModule(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Subscription & Finance Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLeaderboards(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Gamification & Leaderboards Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSecurityModule(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Security & Access Control Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSettingsModule(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Settings & Customization Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) => setState(() => _selectedNavIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFD62828),
        unselectedItemColor: Colors.grey[600],
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(_navigationItems[0]['icon']),
            label: _navigationItems[0]['label'],
          ),
          BottomNavigationBarItem(
            icon: Icon(_navigationItems[1]['icon']),
            label: _navigationItems[1]['label'],
          ),
          BottomNavigationBarItem(
            icon: Icon(_navigationItems[2]['icon']),
            label: _navigationItems[2]['label'],
          ),
          BottomNavigationBarItem(
            icon: Icon(_navigationItems[5]['icon']),
            label: 'More',
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    return _navigationItems[_selectedNavIndex]['label'];
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Navigation',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 20),
            ..._navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                leading: Icon(item['icon'], color: const Color(0xFF1A1E3F)),
                title: Text(
                  item['label'],
                  style: GoogleFonts.montserrat(
                    fontWeight: _selectedNavIndex == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedNavIndex = index);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notifications', style: GoogleFonts.montserrat()),
        content: const Text('No new notifications'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  void _handleProfileAction(String action) {
    switch (action) {
      case 'profile':
        // Navigate to profile
        break;
      case 'settings':
        setState(() => _selectedNavIndex = 8);
        break;
      case 'logout':
        // Handle logout
        break;
    }
  }

  void _handleQuickAction(String action) {
    // Handle quick actions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action clicked'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
    );
  }
}
