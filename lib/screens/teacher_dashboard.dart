import 'package:flutter/material.dart';
import 'teacher_home_page.dart';

/// Deprecated: teacher dashboard removed. Use `TeacherHomePage` (which reuses
/// `StudentHomePage(isTeacher: true)`) instead. This file remains for
/// compatibility but forwards to the new page.
@deprecated
class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherHomePage();
  }
}

  Widget _buildMainContent(bool isSmallScreen, bool isMediumScreen) {
    switch (_selectedNavIndex) {
      case 0:
        return _buildHomeContent(isSmallScreen, isMediumScreen);
      case 1:
        return _buildStudentsContent(isSmallScreen, isMediumScreen);
      case 2:
        return _buildPerformanceContent(isSmallScreen, isMediumScreen);
      case 3:
        return _buildAssignmentsContent(isSmallScreen, isMediumScreen);
      case 4:
        return _buildCommunicationContent(isSmallScreen, isMediumScreen);
      case 5:
        return _buildGamificationContent(isSmallScreen, isMediumScreen);
      case 6:
        return _buildSettingsContent(isSmallScreen, isMediumScreen);
      default:
        return _buildHomeContent(isSmallScreen, isMediumScreen);
    }
  }

  Widget _buildHomeContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section with Uri Mascot
          _buildWelcomeSection(isSmallScreen),
          
          const SizedBox(height: 24),
          
          // Quick Metrics Cards
          _buildQuickMetricsRow(isSmallScreen, isMediumScreen),
          
          const SizedBox(height: 24),
          
          // Main Dashboard Content
          if (isSmallScreen) ...[
            _buildSubjectPerformanceChart(isSmallScreen),
            const SizedBox(height: 20),
            _buildTopStudentsWidget(isSmallScreen),
            const SizedBox(height: 20),
            _buildRecentActivityWidget(isSmallScreen),
            const SizedBox(height: 20),
            _buildClassLeaderboard(isSmallScreen),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSubjectPerformanceChart(isSmallScreen),
                      const SizedBox(height: 20),
                      _buildAssignmentProgressTracker(isSmallScreen),
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
                      _buildClassLeaderboard(isSmallScreen),
                      const SizedBox(height: 20),
                      _buildQuickStatsPanel(isSmallScreen),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildRecentActivityWidget(isSmallScreen),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1E3F), Color(0xFF2A2E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, ${_teacherName.split(' ')[0]}!',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to inspire young minds today? Your students are excited to learn with you!',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '💡 Teaching Tip: Celebrate small wins to boost student confidence',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isSmallScreen) ...[
            const SizedBox(width: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickMetricsRow(bool isSmallScreen, bool isMediumScreen) {
    final metrics = [
      {
        'title': 'Classes Managed',
        'value': '4',
        'subtitle': '18 periods/week',
        'icon': Icons.class_rounded,
        'color': const Color(0xFF2ECC71),
      },
      {
        'title': 'Total Students',
        'value': '156',
        'subtitle': '24 active today',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF2196F3),
      },
      {
        'title': 'Avg Class Score',
        'value': '82.5%',
        'subtitle': '+5.2% this week',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF2ECC71),
      },
      {
        'title': 'Top Student',
        'value': 'Kwame A.',
        'subtitle': '96.5% average',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFFFD700),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSmallScreen ? 2 : (isMediumScreen ? 2 : 4),
        childAspectRatio: isSmallScreen ? 1.3 : 1.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _buildMetricCard(metric, isSmallScreen);
      },
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric, bool isSmallScreen) {
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
                  color: metric['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  metric['icon'],
                  color: metric['color'],
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              const Spacer(),
              if (metric['title'] == 'Avg Class Score')
                const Icon(
                  Icons.trending_up,
                  color: Color(0xFF2ECC71),
                  size: 16,
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            metric['value'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            metric['title'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          
          Text(
            metric['subtitle'],
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: metric['color'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceChart(bool isSmallScreen) {
    final subjects = [
      {'name': 'Mathematics', 'score': 85.2, 'students': 42},
      {'name': 'Integrated Science', 'score': 78.9, 'students': 38},
      {'name': 'Physics', 'score': 82.1, 'students': 35},
      {'name': 'Chemistry', 'score': 76.5, 'students': 33},
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
                'Subject Performance Overview',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'This Week',
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
          
          const SizedBox(height: 20),
          
          ...subjects.map((subject) => _buildSubjectBar(subject, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildSubjectBar(Map<String, dynamic> subject, bool isSmallScreen) {
    Color getScoreColor(double score) {
      if (score >= 80) return const Color(0xFF2ECC71);
      if (score >= 70) return const Color(0xFFFF9800);
      return const Color(0xFFD62828);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject['name'],
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    Text(
                      '${subject['students']} students',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${subject['score'].toStringAsFixed(1)}%',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: getScoreColor(subject['score']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: subject['score'] / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(getScoreColor(subject['score'])),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildTopStudentsWidget(bool isSmallScreen) {
    final students = [
      {'name': 'Kwame Asante', 'class': 'SHS 3A', 'score': 96.5, 'subject': 'Mathematics'},
      {'name': 'Ama Osei', 'class': 'SHS 2B', 'score': 94.8, 'subject': 'Physics'},
      {'name': 'Kofi Mensah', 'class': 'SHS 3A', 'score': 92.1, 'subject': 'Chemistry'},
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
                color: const Color(0xFFFFD700),
                size: isSmallScreen ? 20 : 24,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...students.asMap().entries.map((entry) {
            final index = entry.key;
            final student = entry.value;
            return _buildTopStudentItem(student, index + 1, isSmallScreen);
          }),
          
          const SizedBox(height: 12),
          
          Center(
            child: TextButton(
              onPressed: () => setState(() => _selectedNavIndex = 1),
              child: Text(
                'View All Students →',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: const Color(0xFFD62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStudentItem(Map<String, dynamic> student, int rank, bool isSmallScreen) {
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: getRankColor(rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3 
                ? Icon(
                    rank == 1 ? Icons.emoji_events : Icons.workspace_premium,
                    size: 16,
                    color: Colors.white,
                  )
                : Text(
                    '$rank',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1A1E3F),
            child: Text(
              student['name'].split(' ')[0][0],
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                  '${student['class']} • ${student['subject']}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            '${student['score']}%',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentProgressTracker(bool isSmallScreen) {
    final assignments = [
      {'title': 'Algebra Quiz 3', 'completed': 35, 'total': 42, 'due': 'Today'},
      {'title': 'Physics Lab Report', 'completed': 28, 'total': 38, 'due': 'Tomorrow'},
      {'title': 'Chemistry Past Questions', 'completed': 31, 'total': 35, 'due': '2 days'},
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
                'Assignment Progress',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedNavIndex = 3),
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
          
          ...assignments.map((assignment) => _buildAssignmentItem(assignment, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(Map<String, dynamic> assignment, bool isSmallScreen) {
    final progress = assignment['completed'] / assignment['total'];
    final isOverdue = assignment['due'] == 'Today' && progress < 1.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment['title'],
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue 
                    ? const Color(0xFFD62828).withOpacity(0.1)
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Due ${assignment['due']}',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: isOverdue ? const Color(0xFFD62828) : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 0.8 
                      ? const Color(0xFF2ECC71)
                      : progress >= 0.5 
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFD62828),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${assignment['completed']}/${assignment['total']}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassLeaderboard(bool isSmallScreen) {
    final students = [
      {'name': 'Kwame Asante', 'score': 96.5, 'badges': 12, 'streak': 15},
      {'name': 'Ama Osei', 'score': 94.8, 'badges': 10, 'streak': 12},
      {'name': 'Kofi Mensah', 'score': 92.1, 'badges': 8, 'streak': 9},
      {'name': 'Akosua Boateng', 'score': 89.7, 'badges': 7, 'streak': 6},
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
                'Class Leaderboard',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _selectedNavIndex = 5),
                child: Text(
                  'View Full',
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
          
          ...students.asMap().entries.map((entry) {
            final index = entry.key;
            final student = entry.value;
            return _buildLeaderboardItem(student, index + 1, isSmallScreen);
          }),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> student, int rank, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank == 1 
                ? const Color(0xFFFFD700)
                : rank == 2 
                  ? const Color(0xFFC0C0C0)
                  : rank == 3 
                    ? const Color(0xFFCD7F32)
                    : Colors.grey[300],
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
            child: Text(
              student['name'],
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
          ),
          
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF9800),
                size: 14,
              ),
              Text(
                '${student['streak']}',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: const Color(0xFFFF9800),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 12),
          
          Text(
            '${student['score']}%',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsPanel(bool isSmallScreen) {
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
            'Quick Stats',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 16),
          
          _buildQuickStatItem('Students Online', '18', Icons.circle, const Color(0xFF2ECC71)),
          _buildQuickStatItem('Assignments Due', '3', Icons.assignment_late, const Color(0xFFFF9800)),
          _buildQuickStatItem('Pending Grading', '7', Icons.rate_review, const Color(0xFFD62828)),
          _buildQuickStatItem('Unread Messages', '5', Icons.mail, const Color(0xFF2196F3)),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF1A1E3F),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityWidget(bool isSmallScreen) {
    final activities = [
      {
        'type': 'submission',
        'message': 'Kwame Asante submitted Algebra Quiz 3',
        'score': '95%',
        'time': '2 min ago',
        'icon': Icons.assignment_turned_in_rounded,
      },
      {
        'type': 'achievement',
        'message': 'Ama Osei earned "Physics Master" badge',
        'score': '',
        'time': '15 min ago',
        'icon': Icons.emoji_events_rounded,
      },
      {
        'type': 'improvement',
        'message': 'Kofi Mensah improved by 12% in Chemistry',
        'score': '+12%',
        'time': '1 hour ago',
        'icon': Icons.trending_up_rounded,
      },
      {
        'type': 'concern',
        'message': 'Akosua Boateng needs attention in Mathematics',
        'score': '58%',
        'time': '2 hours ago',
        'icon': Icons.warning_rounded,
      },
      {
        'type': 'login',
        'message': '5 students started study sessions',
        'score': '',
        'time': '3 hours ago',
        'icon': Icons.login_rounded,
      },
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
                'Recent Student Activity',
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
                  'View All Activity',
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
        case 'submission': return const Color(0xFF2ECC71);
        case 'achievement': return const Color(0xFFFFD700);
        case 'improvement': return const Color(0xFF2ECC71);
        case 'concern': return const Color(0xFFD62828);
        case 'login': return const Color(0xFF2196F3);
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
          
          if (activity['score'].isNotEmpty)
            Text(
              activity['score'],
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: getActivityColor(activity['type']),
              ),
            ),
        ],
      ),
    );
  }

  // Placeholder widgets for other modules
  Widget _buildStudentsContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'My Students Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPerformanceContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Performance Reports Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAssignmentsContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Assignments & Content Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCommunicationContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Communication Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGamificationContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Gamification Module\n(Coming Soon)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSettingsContent(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: Text(
          'Settings Module\n(Coming Soon)',
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
        currentIndex: _selectedNavIndex >= 4 ? 3 : _selectedNavIndex,
        onTap: (index) {
          if (index == 3) {
            _showMobileMenu(context);
          } else {
            setState(() => _selectedNavIndex = index);
          }
        },
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
            icon: Icon(_navigationItems[3]['icon']),
            label: _navigationItems[3]['label'],
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Color(0xFF2ECC71)),
              title: Text('3 new submissions', style: GoogleFonts.montserrat()),
              subtitle: Text('Algebra Quiz 3', style: GoogleFonts.montserrat()),
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Color(0xFFFF9800)),
              title: Text('Low performance alert', style: GoogleFonts.montserrat()),
              subtitle: Text('2 students need attention', style: GoogleFonts.montserrat()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action clicked'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
    );
  }

  void _handleProfileAction(String action) {
    switch (action) {
      case 'profile':
        // Navigate to profile
        break;
      case 'classes':
        // Navigate to classes
        break;
      case 'settings':
        setState(() => _selectedNavIndex = 6);
        break;
      case 'logout':
        // Handle logout
        break;
    }
  }
}