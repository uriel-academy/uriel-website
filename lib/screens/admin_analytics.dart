import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  
  bool _isLoading = true;
  Map<String, int> _collectionCounts = {};
  Map<String, dynamic> _analyticsData = {};
  String _selectedDateRange = 'Last 7 days';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _setDateRange(_selectedDateRange);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDateRange(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'Today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
        break;
      case 'Last 7 days':
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
        break;
      case 'Last 30 days':
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
        break;
      case 'Last 90 days':
        _startDate = now.subtract(const Duration(days: 90));
        _endDate = now;
        break;
      case 'All time':
        _startDate = null;
        _endDate = null;
        break;
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      // Load collection counts in parallel
      final futures = await Future.wait([
        _getCollectionCount('users'),
        _getCollectionCount('questions'),
        _getCollectionCount('french_questions'),
        _getCollectionCount('theoryQuestions'),
        _getCollectionCount('quizzes'),
        _getCollectionCount('notes'),
        _getCollectionCount('storybooks'),
        _getCollectionCount('courses'),
        _getCollectionCount('textbook_content'),
        _getCollectionCount('xp_transactions'),
        _getCollectionCount('notifications'),
        _getCollectionCount('feedback'),
        _getCollectionCount('trivia_results'),
        _getCollectionCount('studentSummaries'),
        _getCollectionCount('classAggregates'),
        _getCollectionCount('leaderboardRanks'),
        _getCollectionCount('aiChats'),
        _getCollectionCount('audits'),
        _getUsersByRole(),
        _getQuizStats(),
        _getXPStats(),
        _getContentStats(),
        _getEngagementStats(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getCollectionCount(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).count().get();
      final count = snapshot.count ?? 0;
      setState(() {
        _collectionCounts[collection] = count;
      });
      return count;
    } catch (e) {
      debugPrint('Error getting count for $collection: $e');
      return 0;
    }
  }

  Future<void> _getUsersByRole() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final roleMap = <String, int>{};
      
      for (var doc in snapshot.docs) {
        final role = doc.data()['role'] ?? 'unknown';
        roleMap[role] = (roleMap[role] ?? 0) + 1;
      }
      
      setState(() {
        _analyticsData['usersByRole'] = roleMap;
      });
    } catch (e) {
      debugPrint('Error getting users by role: $e');
    }
  }

  Future<void> _getQuizStats() async {
    try {
      Query query = _firestore.collection('quizzes');
      
      if (_startDate != null) {
        query = query.where('completedAt', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        query = query.where('completedAt', isLessThanOrEqualTo: _endDate);
      }
      
      final snapshot = await query.get();
      
      int totalQuizzes = snapshot.docs.length;
      double totalScore = 0;
      int totalQuestions = 0;
      int totalCorrect = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalScore += (data['score'] ?? 0).toDouble();
        totalQuestions += (data['totalQuestions'] ?? 0) as int;
        totalCorrect += (data['correctAnswers'] ?? 0) as int;
      }
      
      setState(() {
        _analyticsData['quizStats'] = {
          'total': totalQuizzes,
          'averageScore': totalQuizzes > 0 ? totalScore / totalQuizzes : 0,
          'totalQuestions': totalQuestions,
          'totalCorrect': totalCorrect,
          'accuracy': totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0,
        };
      });
    } catch (e) {
      debugPrint('Error getting quiz stats: $e');
    }
  }

  Future<void> _getXPStats() async {
    try {
      Query query = _firestore.collection('xp_transactions');
      
      if (_startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: _startDate);
      }
      if (_endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: _endDate);
      }
      
      final snapshot = await query.get();
      
      int totalTransactions = snapshot.docs.length;
      int totalXP = 0;
      final xpByReason = <String, int>{};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final xp = (data['xp'] ?? 0) as int;
        final reason = data['reason'] ?? 'unknown';
        
        totalXP += xp;
        xpByReason[reason] = (xpByReason[reason] ?? 0) + xp;
      }
      
      setState(() {
        _analyticsData['xpStats'] = {
          'totalTransactions': totalTransactions,
          'totalXP': totalXP,
          'averageXP': totalTransactions > 0 ? totalXP / totalTransactions : 0,
          'byReason': xpByReason,
        };
      });
    } catch (e) {
      debugPrint('Error getting XP stats: $e');
    }
  }

  Future<void> _getContentStats() async {
    try {
      final results = await Future.wait([
        _getCollectionCount('notes'),
        _getCollectionCount('storybooks'),
        _getCollectionCount('textbook_content'),
        _getCollectionCount('textbook_chapters'),
        _getCollectionCount('courses'),
      ]);
      
      setState(() {
        _analyticsData['contentStats'] = {
          'notes': results[0],
          'storybooks': results[1],
          'textbooks': results[2],
          'chapters': results[3],
          'courses': results[4],
        };
      });
    } catch (e) {
      debugPrint('Error getting content stats: $e');
    }
  }

  Future<void> _getEngagementStats() async {
    try {
      final users = await _firestore.collection('users').get();
      
      int activeUsers = 0;
      int totalStreaks = 0;
      int maxStreak = 0;
      
      for (var doc in users.docs) {
        final data = doc.data();
        final lastActive = data['lastActiveAt'] as Timestamp?;
        final streak = (data['currentStreak'] ?? 0) as int;
        
        if (lastActive != null) {
          final daysSinceActive = DateTime.now().difference(lastActive.toDate()).inDays;
          if (daysSinceActive <= 7) activeUsers++;
        }
        
        totalStreaks += streak;
        if (streak > maxStreak) maxStreak = streak;
      }
      
      setState(() {
        _analyticsData['engagementStats'] = {
          'activeUsers': activeUsers,
          'averageStreak': users.docs.isNotEmpty ? totalStreaks / users.docs.length : 0,
          'maxStreak': maxStreak,
        };
      });
    } catch (e) {
      debugPrint('Error getting engagement stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analytics'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAnalytics,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Analytics',
            onPressed: _exportAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Learning', icon: Icon(Icons.school)),
            Tab(text: 'Content', icon: Icon(Icons.library_books)),
            Tab(text: 'Engagement', icon: Icon(Icons.trending_up)),
            Tab(text: 'Collections', icon: Icon(Icons.storage)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateRangeSelector(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildUsersTab(),
                      _buildLearningTab(),
                      _buildContentTab(),
                      _buildEngagementTab(),
                      _buildCollectionsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 20),
          const SizedBox(width: 8),
          const Text('Date Range:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedDateRange,
            items: ['Today', 'Last 7 days', 'Last 30 days', 'Last 90 days', 'All time']
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedDateRange = val;
                  _setDateRange(val);
                });
                _loadAnalytics();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalUsers = _collectionCounts['users'] ?? 0;
    final totalQuizzes = _collectionCounts['quizzes'] ?? 0;
    final totalQuestions = (_collectionCounts['questions'] ?? 0) +
        (_collectionCounts['french_questions'] ?? 0) +
        (_collectionCounts['theoryQuestions'] ?? 0);
    final totalNotes = _collectionCounts['notes'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Key Metrics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard('Total Users', totalUsers, Icons.people, Colors.blue),
              _buildMetricCard('Quizzes Taken', totalQuizzes, Icons.quiz, Colors.green),
              _buildMetricCard('Questions', totalQuestions, Icons.question_answer, Colors.orange),
              _buildMetricCard('Study Notes', totalNotes, Icons.note, Colors.purple),
              _buildMetricCard('XP Earned', _analyticsData['xpStats']?['totalXP'] ?? 0, Icons.stars, Colors.amber),
              _buildMetricCard('Active Users', _analyticsData['engagementStats']?['activeUsers'] ?? 0, Icons.trending_up, Colors.teal),
              _buildMetricCard('AI Chats', _collectionCounts['aiChats'] ?? 0, Icons.smart_toy, Colors.pink),
              _buildMetricCard('Feedback', _collectionCounts['feedback'] ?? 0, Icons.feedback, Colors.indigo),
            ],
          ),
          const SizedBox(height: 32),
          _buildQuizAccuracyChart(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final usersByRole = _analyticsData['usersByRole'] as Map<String, int>? ?? {};
    final totalUsers = _collectionCounts['users'] ?? 0;
    final studentSummaries = _collectionCounts['studentSummaries'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('User Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Users by Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        if (usersByRole.isNotEmpty)
                          ...usersByRole.entries.map((entry) {
                            final percentage = totalUsers > 0 ? (entry.value / totalUsers * 100) : 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(entry.key.toUpperCase()),
                                      Text('${entry.value} (${percentage.toStringAsFixed(1)}%)'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor: Colors.grey[200],
                                      color: _getRoleColor(entry.key),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                        else
                          const Text('No data available'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildStatCard('Total Registered Users', totalUsers, Icons.people),
                    const SizedBox(height: 16),
                    _buildStatCard('Student Summaries', studentSummaries, Icons.summarize),
                    const SizedBox(height: 16),
                    _buildStatCard('Class Aggregates', _collectionCounts['classAggregates'] ?? 0, Icons.class_),
                    const SizedBox(height: 16),
                    _buildStatCard('Leaderboard Entries', _collectionCounts['leaderboardRanks'] ?? 0, Icons.leaderboard),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Role Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...usersByRole.entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getRoleColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(entry.key.toUpperCase())),
                            Text('${entry.value} users', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Text('${((entry.value / totalUsers) * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningTab() {
    final quizStats = _analyticsData['quizStats'] as Map<String, dynamic>? ?? {};
    final xpStats = _analyticsData['xpStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Learning Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard('Total Quizzes', quizStats['total'] ?? 0, Icons.quiz, Colors.blue),
              _buildMetricCard('Avg Score', (quizStats['averageScore'] ?? 0).toStringAsFixed(1), Icons.grade, Colors.green),
              _buildMetricCard('Accuracy', '${(quizStats['accuracy'] ?? 0).toStringAsFixed(1)}%', Icons.check_circle, Colors.orange),
              _buildMetricCard('Questions Answered', quizStats['totalQuestions'] ?? 0, Icons.question_answer, Colors.purple),
              _buildMetricCard('Correct Answers', quizStats['totalCorrect'] ?? 0, Icons.check, Colors.teal),
              _buildMetricCard('XP Transactions', xpStats['totalTransactions'] ?? 0, Icons.account_balance_wallet, Colors.amber),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('XP by Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (xpStats['byReason'] != null)
                    ...(xpStats['byReason'] as Map<String, int>).entries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text('${entry.value} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ))
                  else
                    const Text('No XP data available'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Trivia Results', _collectionCounts['trivia_results'] ?? 0, Icons.psychology),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard('Grade Predictions', _collectionCounts['gradePredictions'] ?? 0, Icons.insights),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    final contentStats = _analyticsData['contentStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Content Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard('Questions (MCQ)', _collectionCounts['questions'] ?? 0, Icons.radio_button_checked, Colors.blue),
              _buildMetricCard('French Questions', _collectionCounts['french_questions'] ?? 0, Icons.language, Colors.pink),
              _buildMetricCard('Theory Questions', _collectionCounts['theoryQuestions'] ?? 0, Icons.assignment, Colors.purple),
              _buildMetricCard('Study Notes', contentStats['notes'] ?? 0, Icons.note, Colors.green),
              _buildMetricCard('Storybooks', contentStats['storybooks'] ?? 0, Icons.menu_book, Colors.orange),
              _buildMetricCard('Textbooks', contentStats['textbooks'] ?? 0, Icons.book, Colors.indigo),
              _buildMetricCard('Courses', contentStats['courses'] ?? 0, Icons.school, Colors.teal),
              _buildMetricCard('Notifications Sent', _collectionCounts['notifications'] ?? 0, Icons.notifications, Colors.amber),
              _buildMetricCard('Lesson Plans', _collectionCounts['lesson_plans'] ?? 0, Icons.event_note, Colors.cyan),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Content Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildContentBreakdownBar('Questions (MCQ)', _collectionCounts['questions'] ?? 0, Colors.blue),
                  _buildContentBreakdownBar('French Questions', _collectionCounts['french_questions'] ?? 0, Colors.pink),
                  _buildContentBreakdownBar('Theory Questions', _collectionCounts['theoryQuestions'] ?? 0, Colors.purple),
                  _buildContentBreakdownBar('Study Notes', contentStats['notes'] ?? 0, Colors.green),
                  _buildContentBreakdownBar('Storybooks', contentStats['storybooks'] ?? 0, Colors.orange),
                  _buildContentBreakdownBar('Textbooks', contentStats['textbooks'] ?? 0, Colors.indigo),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementTab() {
    final engagementStats = _analyticsData['engagementStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Engagement Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard('Active Users (7d)', engagementStats['activeUsers'] ?? 0, Icons.people_outline, Colors.blue),
              _buildMetricCard('Avg Streak', (engagementStats['averageStreak'] ?? 0).toStringAsFixed(1), Icons.local_fire_department, Colors.orange),
              _buildMetricCard('Max Streak', engagementStats['maxStreak'] ?? 0, Icons.whatshot, Colors.red),
              _buildMetricCard('Total Notifications', _collectionCounts['notifications'] ?? 0, Icons.notifications_active, Colors.amber),
              _buildMetricCard('Feedback Submitted', _collectionCounts['feedback'] ?? 0, Icons.rate_review, Colors.green),
              _buildMetricCard('AI Chat Sessions', _collectionCounts['aiChats'] ?? 0, Icons.chat, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Engagement Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.green),
                    title: const Text('Active Users (Last 7 Days)'),
                    trailing: Text('${engagementStats['activeUsers'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                    title: const Text('Average Streak'),
                    trailing: Text('${(engagementStats['averageStreak'] ?? 0).toStringAsFixed(1)} days', style: const TextStyle(fontSize: 18)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.whatshot, color: Colors.red),
                    title: const Text('Longest Streak'),
                    trailing: Text('${engagementStats['maxStreak'] ?? 0} days', style: const TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsTab() {
    final collections = [
      {'name': 'users', 'label': 'Users', 'icon': Icons.people},
      {'name': 'questions', 'label': 'Questions (MCQ)', 'icon': Icons.quiz},
      {'name': 'french_questions', 'label': 'French Questions', 'icon': Icons.language},
      {'name': 'theoryQuestions', 'label': 'Theory Questions', 'icon': Icons.assignment},
      {'name': 'quizzes', 'label': 'Quiz Attempts', 'icon': Icons.assignment_turned_in},
      {'name': 'xp_transactions', 'label': 'XP Transactions', 'icon': Icons.account_balance_wallet},
      {'name': 'notes', 'label': 'Study Notes', 'icon': Icons.note},
      {'name': 'storybooks', 'label': 'Storybooks', 'icon': Icons.menu_book},
      {'name': 'courses', 'label': 'Courses', 'icon': Icons.school},
      {'name': 'textbook_content', 'label': 'Textbook Content', 'icon': Icons.book},
      {'name': 'studentSummaries', 'label': 'Student Summaries', 'icon': Icons.summarize},
      {'name': 'classAggregates', 'label': 'Class Aggregates', 'icon': Icons.class_},
      {'name': 'leaderboardRanks', 'label': 'Leaderboard Ranks', 'icon': Icons.leaderboard},
      {'name': 'notifications', 'label': 'Notifications', 'icon': Icons.notifications},
      {'name': 'feedback', 'label': 'Feedback', 'icon': Icons.feedback},
      {'name': 'trivia_results', 'label': 'Trivia Results', 'icon': Icons.psychology},
      {'name': 'aiChats', 'label': 'AI Chats', 'icon': Icons.smart_toy},
      {'name': 'audits', 'label': 'Audit Logs', 'icon': Icons.history},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Firestore Collections', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Real-time document counts for all collections', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: collections.map((collection) {
                final count = _collectionCounts[collection['name']] ?? 0;
                return ListTile(
                  leading: Icon(collection['icon'] as IconData, color: Colors.blue),
                  title: Text(collection['label'] as String),
                  subtitle: Text(collection['name'] as String),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, dynamic value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBreakdownBar(String label, int count, Color color) {
    final maxCount = [
      _collectionCounts['questions'] ?? 0,
      _collectionCounts['french_questions'] ?? 0,
      _collectionCounts['theoryQuestions'] ?? 0,
      _analyticsData['contentStats']?['notes'] ?? 0,
      _analyticsData['contentStats']?['storybooks'] ?? 0,
      _analyticsData['contentStats']?['textbooks'] ?? 0,
    ].reduce((a, b) => a > b ? a : b);

    final percentage = maxCount > 0 ? count / maxCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizAccuracyChart() {
    final quizStats = _analyticsData['quizStats'] as Map<String, dynamic>? ?? {};
    final accuracy = (quizStats['accuracy'] ?? 0).toDouble();
    final remaining = (100 - accuracy).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overall Quiz Accuracy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(0.1),
                          border: Border.all(color: Colors.green, width: 8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${accuracy.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const Text('Accuracy', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 12, height: 12, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Correct'),
                          const SizedBox(width: 16),
                          Container(width: 12, height: 12, color: Colors.red.withOpacity(0.3)),
                          const SizedBox(width: 8),
                          const Text('Incorrect'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow('Total Questions', quizStats['totalQuestions'] ?? 0, Icons.quiz),
                      const SizedBox(height: 16),
                      _buildStatRow('Correct Answers', quizStats['totalCorrect'] ?? 0, Icons.check_circle, color: Colors.green),
                      const SizedBox(height: 16),
                      _buildStatRow('Incorrect Answers', (quizStats['totalQuestions'] ?? 0) - (quizStats['totalCorrect'] ?? 0), Icons.cancel, color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return Colors.blue;
      case 'teacher':
        return Colors.green;
      case 'school_admin':
        return Colors.orange;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _exportAnalytics() {
    // TODO: Implement CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analytics export feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
