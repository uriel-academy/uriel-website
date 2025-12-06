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
      backgroundColor: const Color(0xFFF5F5F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
          : CustomScrollView(
              slivers: [
                // Analytics Header Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Platform Analytics',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Real-time insights and metrics',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _buildActionButton(
                                  'Refresh',
                                  Icons.refresh,
                                  _loadAnalytics,
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                  'Export',
                                  Icons.download,
                                  _exportAnalytics,
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Date Range Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _buildDateRangeChip('Today'),
                              _buildDateRangeChip('Last 7 days'),
                              _buildDateRangeChip('Last 30 days'),
                              _buildDateRangeChip('Last 90 days'),
                              _buildDateRangeChip('All time'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab Bar
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: const Color(0xFF007AFF),
                      unselectedLabelColor: Colors.grey[600],
                      indicatorColor: const Color(0xFF007AFF),
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Users'),
                        Tab(text: 'Learning'),
                        Tab(text: 'Content'),
                        Tab(text: 'Engagement'),
                        Tab(text: 'Collections'),
                      ],
                    ),
                  ),
                ),

                // Tab Content
                SliverFillRemaining(
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(String range) {
    final isSelected = _selectedDateRange == range;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDateRange = range;
            _setDateRange(range);
          });
          _loadAnalytics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            range,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF007AFF) : Colors.grey[600],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
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
          const SizedBox(height: 24),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Users by Role',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (usersByRole.isNotEmpty)
                        ...usersByRole.entries.map((entry) {
                          final percentage = totalUsers > 0 ? (entry.value / totalUsers * 100) : 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      entry.key.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[900],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[100],
                                    color: _getRoleColor(entry.key),
                                    minHeight: 6,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildStatCard('Total Registered Users', totalUsers, Icons.people),
                    const SizedBox(height: 12),
                    _buildStatCard('Student Summaries', studentSummaries, Icons.summarize),
                    const SizedBox(height: 12),
                    _buildStatCard('Class Aggregates', _collectionCounts['classAggregates'] ?? 0, Icons.class_),
                    const SizedBox(height: 12),
                    _buildStatCard('Leaderboard Entries', _collectionCounts['leaderboardRanks'] ?? 0, Icons.leaderboard),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningTab() {
    final quizStats = _analyticsData['quizStats'] as Map<String, dynamic>? ?? {};
    final xpStats = _analyticsData['xpStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildMetricCard('Total Quizzes', quizStats['total'] ?? 0, Icons.quiz, Colors.blue),
              _buildMetricCard('Avg Score', (quizStats['averageScore'] ?? 0).toStringAsFixed(1), Icons.grade, Colors.green),
              _buildMetricCard('Accuracy', '${(quizStats['accuracy'] ?? 0).toStringAsFixed(1)}%', Icons.check_circle, Colors.orange),
              _buildMetricCard('Questions Answered', quizStats['totalQuestions'] ?? 0, Icons.question_answer, Colors.purple),
              _buildMetricCard('Correct Answers', quizStats['totalCorrect'] ?? 0, Icons.check, Colors.teal),
              _buildMetricCard('XP Transactions', xpStats['totalTransactions'] ?? 0, Icons.account_balance_wallet, Colors.amber),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'XP by Activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 16),
                if (xpStats['byReason'] != null)
                  ...(xpStats['byReason'] as Map<String, int>).entries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value} XP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                          ],
                        ),
                      ))
                else
                  const Text('No XP data available'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab() {
    final contentStats = _analyticsData['contentStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildMetricCard('Questions (MCQ)', _collectionCounts['questions'] ?? 0, Icons.radio_button_checked, Colors.blue),
              _buildMetricCard('French Questions', _collectionCounts['french_questions'] ?? 0, Icons.language, Colors.pink),
              _buildMetricCard('Theory Questions', _collectionCounts['theoryQuestions'] ?? 0, Icons.assignment, Colors.purple),
              _buildMetricCard('Study Notes', contentStats['notes'] ?? 0, Icons.note, Colors.green),
              _buildMetricCard('Storybooks', contentStats['storybooks'] ?? 0, Icons.menu_book, Colors.orange),
              _buildMetricCard('Textbooks', contentStats['textbooks'] ?? 0, Icons.book, Colors.indigo),
              _buildMetricCard('Courses', contentStats['courses'] ?? 0, Icons.school, Colors.teal),
              _buildMetricCard('Notifications', _collectionCounts['notifications'] ?? 0, Icons.notifications, Colors.amber),
              _buildMetricCard('Lesson Plans', _collectionCounts['lesson_plans'] ?? 0, Icons.event_note, Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementTab() {
    final engagementStats = _analyticsData['engagementStats'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildMetricCard('Active Users (7d)', engagementStats['activeUsers'] ?? 0, Icons.people_outline, Colors.blue),
              _buildMetricCard('Avg Streak', (engagementStats['averageStreak'] ?? 0).toStringAsFixed(1), Icons.local_fire_department, Colors.orange),
              _buildMetricCard('Max Streak', engagementStats['maxStreak'] ?? 0, Icons.whatshot, Colors.red),
              _buildMetricCard('Notifications', _collectionCounts['notifications'] ?? 0, Icons.notifications_active, Colors.amber),
              _buildMetricCard('Feedback', _collectionCounts['feedback'] ?? 0, Icons.rate_review, Colors.green),
              _buildMetricCard('AI Chats', _collectionCounts['aiChats'] ?? 0, Icons.chat, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsTab() {
    final collections = [
      {'name': 'users', 'label': 'Users'},
      {'name': 'questions', 'label': 'Questions (MCQ)'},
      {'name': 'french_questions', 'label': 'French Questions'},
      {'name': 'theoryQuestions', 'label': 'Theory Questions'},
      {'name': 'quizzes', 'label': 'Quiz Attempts'},
      {'name': 'xp_transactions', 'label': 'XP Transactions'},
      {'name': 'notes', 'label': 'Study Notes'},
      {'name': 'storybooks', 'label': 'Storybooks'},
      {'name': 'courses', 'label': 'Courses'},
      {'name': 'textbook_content', 'label': 'Textbook Content'},
      {'name': 'studentSummaries', 'label': 'Student Summaries'},
      {'name': 'classAggregates', 'label': 'Class Aggregates'},
      {'name': 'leaderboardRanks', 'label': 'Leaderboard Ranks'},
      {'name': 'notifications', 'label': 'Notifications'},
      {'name': 'feedback', 'label': 'Feedback'},
      {'name': 'trivia_results', 'label': 'Trivia Results'},
      {'name': 'aiChats', 'label': 'AI Chats'},
      {'name': 'audits', 'label': 'Audit Logs'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firestore Collections',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time document counts for all collections',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                ...collections.map((collection) {
                  final count = _collectionCounts[collection['name']] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              collection['name'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, dynamic value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizAccuracyChart() {
    final quizStats = _analyticsData['quizStats'] as Map<String, dynamic>? ?? {};
    final accuracy = (quizStats['accuracy'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Quiz Accuracy',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 20),
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
                        color: const Color(0xFF34C759).withValues(alpha: 0.1),
                        border: Border.all(color: const Color(0xFF34C759), width: 8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${accuracy.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF34C759),
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'Accuracy',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow('Total Questions', quizStats['totalQuestions'] ?? 0, null),
                    const SizedBox(height: 16),
                    _buildStatRow('Correct Answers', quizStats['totalCorrect'] ?? 0, null, color: const Color(0xFF34C759)),
                    const SizedBox(height: 16),
                    _buildStatRow('Incorrect Answers', (quizStats['totalQuestions'] ?? 0) - (quizStats['totalCorrect'] ?? 0), null, color: const Color(0xFFFF3B30)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData? icon, {Color? color}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey[900],
          ),
        ),
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
