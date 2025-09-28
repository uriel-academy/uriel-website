import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'past_questions.dart';
import 'textbooks.dart';
import 'trivia.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Student metrics data
  int questionsAnswered = 125;
  int textbooksRead = 8;
  int triviaScore = 850;
  int dailyStreak = 12;
  double averageScore = 78.5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Uriel Academy'),
        backgroundColor: const Color(0xFF1A1E3F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showProfileMenu(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.quiz), text: 'Questions'),
            Tab(icon: Icon(Icons.menu_book), text: 'Textbooks'),
            Tab(icon: Icon(Icons.psychology), text: 'Trivia'),
            Tab(icon: Icon(Icons.assessment), text: 'Mock'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildQuestionsTab(),
          _buildTextbooksTab(),
          _buildTriviaTab(),
          _buildMockTab(),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s your learning progress',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _buildMetricsGrid(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Questions Answered',
          questionsAnswered.toString(),
          Icons.quiz_outlined,
          const Color(0xFF4CAF50),
        ),
        _buildMetricCard(
          'Textbooks Read',
          textbooksRead.toString(),
          Icons.menu_book_outlined,
          const Color(0xFF2196F3),
        ),
        _buildMetricCard(
          'Daily Streak',
          '$dailyStreak days',
          Icons.local_fire_department,
          const Color(0xFFFF9800),
        ),
        _buildMetricCard(
          'Average Score',
          '${averageScore.toStringAsFixed(1)}%',
          Icons.trending_up,
          const Color(0xFF9C27B0),
        ),
        _buildMetricCard(
          'Trivia Points',
          triviaScore.toString(),
          Icons.psychology,
          const Color(0xFFE91E63),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: color),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              'Completed Math Quiz',
              '2 hours ago',
              Icons.quiz,
              const Color(0xFF4CAF50),
            ),
            _buildActivityItem(
              'Read Physics Textbook Ch. 5',
              '1 day ago',
              Icons.menu_book,
              const Color(0xFF2196F3),
            ),
            _buildActivityItem(
              'Trivia Challenge - 8/10',
              '2 days ago',
              Icons.psychology,
              const Color(0xFFE91E63),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  'Start Quiz',
                  Icons.play_arrow,
                  const Color(0xFF4CAF50),
                  () => _tabController.animateTo(1),
                ),
                _buildQuickActionButton(
                  'Read Book',
                  Icons.menu_book,
                  const Color(0xFF2196F3),
                  () => _tabController.animateTo(2),
                ),
                _buildQuickActionButton(
                  'Play Trivia',
                  Icons.psychology,
                  const Color(0xFFE91E63),
                  () => _tabController.animateTo(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Past Questions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your examination type',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildExamTypeCard(
                  'BECE',
                  'Basic Education Certificate Examination',
                  Icons.school,
                  const Color(0xFF4CAF50),
                  () => _showSubjectPicker('BECE'),
                ),
                _buildExamTypeCard(
                  'WASSCE',
                  'West African Senior School Certificate Examination',
                  Icons.workspace_premium,
                  const Color(0xFF2196F3),
                  () => _showSubjectPicker('WASSCE'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextbooksTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Digital Textbooks',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your education level',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildExamTypeCard(
                  'JHS',
                  'Junior High School Textbooks',
                  Icons.menu_book,
                  const Color(0xFFFF9800),
                  () => _showTextbookPicker('JHS'),
                ),
                _buildExamTypeCard(
                  'SHS',
                  'Senior High School Textbooks',
                  Icons.library_books,
                  const Color(0xFF9C27B0),
                  () => _showTextbookPicker('SHS'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriviaTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Trivia Challenge',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Test your knowledge and have fun!',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 64,
                    color: Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Number of Questions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTriviaOptionButton('10', 10),
                      _buildTriviaOptionButton('20', 20),
                      _buildTriviaOptionButton('40', 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Mock Examinations',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Practice with full-length mock exams',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: 1,
              childAspectRatio: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildExamTypeCard(
                  'JHS Mock',
                  'Junior High School Mock Examinations',
                  Icons.assessment,
                  const Color(0xFF4CAF50),
                  () => _showMockPicker('JHS'),
                ),
                _buildExamTypeCard(
                  'SHS Mock',
                  'Senior High School Mock Examinations',
                  Icons.assignment,
                  const Color(0xFF2196F3),
                  () => _showMockPicker('SHS'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamTypeCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriviaOptionButton(String label, int questionCount) {
    return ElevatedButton(
      onPressed: () => _startTrivia(questionCount),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showSubjectPicker(String examType) {
    final subjects = examType == 'BECE' 
      ? ['Mathematics', 'English', 'Science', 'Social Studies', 'Religious and Moral Education', 'ICT']
      : ['Mathematics', 'English', 'Physics', 'Chemistry', 'Biology', 'Economics', 'Geography', 'History'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$examType Subjects'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: subjects.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(subjects[index]),
              onTap: () {
                Navigator.pop(context);
                _showYearPicker(examType, subjects[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showYearPicker(String examType, String subject) {
    final years = List.generate(10, (index) => (2024 - index).toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$subject - Select Year'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: years.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(years[index]),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PastQuestionsPage(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showTextbookPicker(String level) {
    final subjects = level == 'JHS'
      ? ['Mathematics', 'English', 'Science', 'Social Studies', 'RME', 'ICT']
      : ['Mathematics', 'English', 'Physics', 'Chemistry', 'Biology', 'Economics', 'Geography', 'History', 'Literature'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$level Textbooks'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: subjects.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(subjects[index]),
              onTap: () {
                Navigator.pop(context);
                _showTextbookYearPicker(level, subjects[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showTextbookYearPicker(String level, String subject) {
    final forms = level == 'JHS' ? ['Form 1', 'Form 2', 'Form 3'] : ['Form 1', 'Form 2', 'Form 3'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$subject - Select Form'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: forms.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(forms[index]),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TextbooksPage(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showMockPicker(String level) {
    final subjects = level == 'JHS'
      ? ['Mathematics', 'English', 'Science', 'Social Studies']
      : ['Mathematics', 'English', 'Physics', 'Chemistry', 'Biology', 'Economics'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$level Mock Exams'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: subjects.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(subjects[index]),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to mock exam page
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Mock exam for ${subjects[index]} coming soon!')),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _startTrivia(int questionCount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TriviaPage(questionCount: questionCount),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}