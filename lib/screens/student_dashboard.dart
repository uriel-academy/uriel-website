import 'package:flutter/material.dart';
import 'subject_detail.dart';
import 'past_questions_search_page.dart';
import 'textbooks.dart';
// Removed unused import 'mock_exams.dart'
import 'ai_tools.dart';
import 'gamification.dart';
import 'calm_mode.dart';
import 'profile_analytics.dart';
import 'student_motivation.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final List<String> motivationMessages = [
    'You are making great progress!',
    'Every mistake is a learning opportunity.',
    'Stay focused and keep pushing forward.',
    'Success is built on daily effort.',
    'Believe in yourself and your abilities.',
  ];
  int quizzesCompleted = 0;
  int textbooksRead = 0;
  int aiToolsUsed = 0;
  int calmModeActivated = 0;
  bool largeFont = false;
  bool offlineMode = false;
  int dailyStreak = 5;

  void _updateProgress({int? quizzes, int? textbooks, int? aiTools, int? calmMode}) {
    setState(() {
      if (quizzes != null) quizzesCompleted += quizzes;
      if (textbooks != null) textbooksRead += textbooks;
      if (aiTools != null) aiToolsUsed += aiTools;
      if (calmMode != null) calmModeActivated += calmMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSubjectGrid(),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 24),
            _buildAnalyticsCard(),
            const SizedBox(height: 24),
            StudentMotivationCard(messages: motivationMessages),
            const SizedBox(height: 24),
            _buildCalmModeCard(context),
            const SizedBox(height: 24),
            _buildGamificationCard(context),
            const SizedBox(height: 24),
            _buildAccessibilityCard(),
            const SizedBox(height: 12),
            _buildEngagementCard(),
            const SizedBox(height: 12),
            _buildPerformanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    final subjects = [
      'Math', 'English', 'Biology', 'Chemistry', 'Physics', 'Economics', 'Literature', 'Civic', 'Geography', 'History', 'Further Math', 'Computer',
    ];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subjects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, i) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectDetailPage(subject: subjects[i]),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(subjects[i], style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _dashboardAction(context, Icons.quiz, 'Past Questions', () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PastQuestionsSearchPage(),
          ));
        }),
        _dashboardAction(context, Icons.menu_book, 'Textbooks', () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => TextbooksPage(onTextbookRead: () => _updateProgress(textbooks: 1)),
          ));
        }),
        _dashboardAction(context, Icons.psychology, 'AI Tools', () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AIToolsPage(onAIToolUsed: () => _updateProgress(aiTools: 1)),
          ));
        }),
        _dashboardAction(context, Icons.self_improvement, 'Calm Mode', () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CalmModePage(onCalmModeActivated: () => _updateProgress(calmMode: 1)),
          ));
        }),
      ],
    );
  }

  Widget _dashboardAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF1A1E3F),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileAnalyticsPage()));
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Track your progress, strengths, and areas to improve.'),
                SizedBox(height: 8),
                LinearProgressIndicator(value: 0.7, minHeight: 8, backgroundColor: Color(0xFFE0E0E0)),
                SizedBox(height: 8),
                Text('70% completion this week!'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalmModeCard(BuildContext context) {
    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CalmModePage()));
        },
        child: Card(
          color: const Color(0xFF2ECC71),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.self_improvement, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Calm Learning Mode: Focus, relax, and learn better with Uriel.', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamificationCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.emoji_events, color: Color(0xFFD62828)),
        title: const Text('Gamification'),
        subtitle: const Text('Badges, points, leaderboard'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => GamificationPage(
              quizzesCompleted: quizzesCompleted,
              textbooksRead: textbooksRead,
              aiToolsUsed: aiToolsUsed,
              calmModeActivated: calmModeActivated,
            ),
          ));
        },
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.text_fields, color: Color(0xFFD62828)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Large Font', style: TextStyle(fontSize: 16))),
            Switch(
              value: largeFont,
              onChanged: (val) {
                setState(() {
                  largeFont = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Color(0xFFD62828)),
            const SizedBox(width: 12),
            Expanded(child: Text('Daily Streak: $dailyStreak days', style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.offline_bolt, color: Color(0xFFD62828)),
            const SizedBox(width: 12),
            Expanded(child: Text(offlineMode ? 'Offline Mode: ON' : 'Offline Mode: OFF', style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}
