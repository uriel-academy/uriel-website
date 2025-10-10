import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../services/xp_service.dart';
import '../services/motivational_service.dart';

class LeaderboardPage extends StatefulWidget {
  final bool isEmbedded; // Whether it's embedded in home page or standalone
  final VoidCallback? onStartQuiz; // Callback to navigate to trivia
  
  const LeaderboardPage({super.key, this.isEmbedded = true, this.onStartQuiz});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _categoryTabController;
  String _selectedPeriod = 'All Time';
  String _selectedScope = 'National';
  String _selectedCategory = 'Overall'; // Overall, Trivia, BECE, WASSCE, etc.
  String _selectedSubCategory = 'Overall'; // For subject-specific rankings
  
  List<LeaderboardEntry> _leaderboardData = [];
  LeaderboardEntry? _currentUserEntry;
  bool _isLoading = true;
  
  String _motivationalMessage = '';
  String _milestoneMessage = '';
  int _xpToNextTier = 0;
  
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];
  final List<String> _scopes = ['My School', 'Regional', 'National', 'Global'];
  
  // Trivia categories
  final List<String> _triviaCategories = [
    'Overall',
    'African History',
    'Art and Culture',
    'Economics',
    'Geography',
    'Ghana History',
    'Literature',
    'Politics',
    'Science',
    'Sports',
    'Technology',
    'World History',
    'World Leaders'
  ];
  
  // BECE subjects
  final List<String> _beceSubjects = [
    'Overall',
    'Mathematics',
    'English',
    'Science',
    'Social Studies',
    'ICT',
    'RME'
  ];
  
  // WASSCE subjects
  final List<String> _wasscceSubjects = [
    'Overall',
    'Mathematics',
    'English',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Economics',
    'Government',
    'Literature'
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _categoryTabController = TabController(length: 13, vsync: this); // For trivia by default
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _getMainCategoryName(_tabController.index);
          _selectedSubCategory = 'Overall';
          _updateCategoryTabController();
        });
        _loadLeaderboardData();
      }
    });
    
    _categoryTabController.addListener(() {
      if (!_categoryTabController.indexIsChanging) {
        setState(() {
          _selectedSubCategory = _getCurrentSubCategories()[_categoryTabController.index];
        });
        _loadLeaderboardData();
      }
    });
    
    _loadLeaderboardData();
  }
  
  void _updateCategoryTabController() {
    _categoryTabController.dispose();
    final categories = _getCurrentSubCategories();
    _categoryTabController = TabController(length: categories.length, vsync: this);
  }
  
  String _getMainCategoryName(int index) {
    switch (index) {
      case 0: return 'Overall';
      case 1: return 'Trivia';
      case 2: return 'BECE';
      case 3: return 'WASSCE';
      case 4: return 'Stories';
      case 5: return 'Textbooks';
      default: return 'Overall';
    }
  }
  
  List<String> _getCurrentSubCategories() {
    switch (_selectedCategory) {
      case 'Trivia':
        return _triviaCategories;
      case 'BECE':
        return _beceSubjects;
      case 'WASSCE':
        return _wasscceSubjects;
      default:
        return ['Overall'];
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _categoryTabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLeaderboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get user's total XP from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      
      // Load all users with XP for leaderboard
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('totalXP', isGreaterThan: 0)
          .orderBy('totalXP', descending: true)
          .limit(200) // Increased to get more users for filtering
          .get();
      
      // Calculate scores for each user based on selected category
      Map<String, UserCategoryStats> userStats = {};
      
      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        final stats = await _calculateUserStats(userId, _selectedCategory, _selectedSubCategory);
        if (stats.score > 0) {
          userStats[userId] = stats;
        }
      }
      
      // Sort by score
      var sortedEntries = userStats.entries.toList()
        ..sort((a, b) => b.value.score.compareTo(a.value.score));
      
      // Take top 100
      sortedEntries = sortedEntries.take(100).toList();
      
      _leaderboardData = [];
      int rank = 1;
      
      for (var entry in sortedEntries) {
        final userId = entry.key;
        final stats = entry.value;
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        final data = userDoc.data();
        if (data == null) continue;
        
        final leaderboardEntry = LeaderboardEntry(
          rank: rank,
          userId: userId,
          username: (data['displayName'] as String?) ?? 'Student',
          school: (data['school'] as String?) ?? 'Ghana School',
          xp: stats.score,
          avatarUrl: data['photoURL'] as String?,
          questionsAnswered: stats.totalQuestions,
          accuracy: stats.totalQuestions > 0 ? (stats.correctAnswers / stats.totalQuestions * 100) : 0,
          streak: 0,
          tier: _getTier(stats.score),
        );
        
        _leaderboardData.add(leaderboardEntry);
        
        if (userId == user.uid) {
          _currentUserEntry = leaderboardEntry;
        }
        
        rank++;
      }
      
      // If current user not in top 100, calculate their stats and add separately
      if (_currentUserEntry == null) {
        final userStats = await _calculateUserStats(user.uid, _selectedCategory, _selectedSubCategory);
        _currentUserEntry = LeaderboardEntry(
          rank: rank,
          userId: user.uid,
          username: user.displayName ?? 'Student',
          school: userData?['school'] as String? ?? 'My School',
          xp: userStats.score,
          avatarUrl: user.photoURL,
          questionsAnswered: userStats.totalQuestions,
          accuracy: userStats.totalQuestions > 0 ? (userStats.correctAnswers / userStats.totalQuestions * 100) : 0,
          streak: 0,
          tier: _getTier(userStats.score),
        );
      }

      // Generate motivational messages
      if (_currentUserEntry != null) {
        final motivService = MotivationalService();
        _motivationalMessage = motivService.getRankBasedMessage(
          _currentUserEntry!.rank,
          _currentUserEntry!.xp,
        );
        _xpToNextTier = XPService().getXPToNextTier(_currentUserEntry!.xp);
        _milestoneMessage = motivService.getMilestoneMessage(
          _currentUserEntry!.rank,
          _xpToNextTier,
        );
      }
      
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<UserCategoryStats> _calculateUserStats(String userId, String category, String subCategory) async {
    try {
      var query = FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId);
      
      // Apply category filter
      if (category == 'Trivia') {
        query = query.where('quizType', isEqualTo: 'trivia');
        if (subCategory != 'Overall') {
          // Filter by trivia category (e.g., 'African History')
          query = query.where('category', isEqualTo: subCategory.toLowerCase().replaceAll(' ', '_'));
        }
      } else if (category == 'BECE') {
        query = query.where('quizType', isEqualTo: 'bece');
        if (subCategory != 'Overall') {
          query = query.where('subject', isEqualTo: subCategory);
        }
      } else if (category == 'WASSCE') {
        query = query.where('quizType', isEqualTo: 'wassce');
        if (subCategory != 'Overall') {
          query = query.where('subject', isEqualTo: subCategory);
        }
      } else if (category == 'Stories') {
        query = query.where('quizType', isEqualTo: 'story');
      } else if (category == 'Textbooks') {
        query = query.where('quizType', isEqualTo: 'textbook');
      }
      // For 'Overall', no filter - includes all quiz types
      
      final quizSnapshot = await query.get();
      
      int totalCorrect = 0;
      int totalQuestions = 0;
      int totalXP = 0;
      
      for (var doc in quizSnapshot.docs) {
        final data = doc.data();
        totalCorrect += (data['correctAnswers'] as int?) ?? 0;
        totalQuestions += (data['totalQuestions'] as int?) ?? 0;
        totalXP += (data['xpEarned'] as int?) ?? 0;
      }
      
      // Use XP as score, or calculate based on performance
      int score = totalXP > 0 ? totalXP : (totalCorrect * 5);
      
      return UserCategoryStats(
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: totalCorrect,
      );
    } catch (e) {
      debugPrint('Error calculating user stats: $e');
      return UserCategoryStats(score: 0, totalQuestions: 0, correctAnswers: 0);
    }
  }
  
  String _getTier(int xp) {
    if (xp >= 10000) return 'Legend';
    if (xp >= 5000) return 'Diamond';
    if (xp >= 2500) return 'Platinum';
    if (xp >= 1000) return 'Gold';
    if (xp >= 500) return 'Silver';
    return 'Bronze';
  }
  
  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Legend': return const Color(0xFF8B5CF6); // Purple
      case 'Diamond': return const Color(0xFF3B82F6); // Blue
      case 'Platinum': return const Color(0xFF6B7280); // Gray
      case 'Gold': return const Color(0xFFFFD700); // Gold
      case 'Silver': return const Color(0xFFC0C0C0); // Silver
      default: return const Color(0xFFCD7F32); // Bronze
    }
  }
  
  void _shareRank() {
    if (_currentUserEntry == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Share Your Rank',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F), // Uriel Navy
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Show your friends how you\'re doing!',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            _buildShareButton(
              'Facebook',
              Icons.facebook,
              const Color(0xFF3B82F6), // Blue
              _getShareMessage('facebook'),
            ),
            const SizedBox(height: 12),
            _buildShareButton(
              'Instagram',
              Icons.camera_alt,
              const Color(0xFF8B5CF6), // Purple
              _getShareMessage('instagram'),
            ),
            const SizedBox(height: 12),
            _buildShareButton(
              'X (Twitter)',
              Icons.close,
              const Color(0xFF6B7280), // Pastel gray
              _getShareMessage('twitter'),
            ),
            const SizedBox(height: 12),
            _buildShareButton(
              'WhatsApp',
              Icons.chat,
              const Color(0xFFA8D8B9), // Pastel mint green
              _getShareMessage('whatsapp'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShareButton(String platform, IconData icon, Color color, String message) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          Share.share(message);
        },
        icon: Icon(icon, size: 20),
        label: Text(
          platform,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  
  String _getShareMessage(String platform) {
    if (_currentUserEntry == null) return '';
    
    final rank = _currentUserEntry!.rank;
    final xp = _currentUserEntry!.xp;
    final tier = _currentUserEntry!.tier;
    const url = 'https://uriel.academy';
    
    final baseMessage = '''🏆 I'm ranked #$rank on Uriel Academy with $xp XP!
$tier Tier 🌟

Think you can beat me? 💪🔥
Join the challenge 👉 $url

#UrielAcademy #LearnPracticeSucceed #Leaderboard''';
    
    return baseMessage;
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    // If embedded in home page, don't use Scaffold
    if (widget.isEmbedded) {
      return CustomScrollView(
        slivers: [
          // Page Title Header (no back button when embedded)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hall of Fame',
                    style: GoogleFonts.playfairDisplay(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 20 : 24,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFFD62828)),
                    onPressed: _shareRank,
                    tooltip: 'Share Your Rank',
                  ),
                ],
              ),
            ),
          ),
          
          // Your Rank Card
          if (_currentUserEntry != null)
            SliverToBoxAdapter(
              child: _buildYourRankCard(isMobile),
            ),

          // Motivational Banner
          if (_motivationalMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildMotivationalBanner(isMobile),
            ),

          // Milestone Progress
          if (_milestoneMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildMilestoneCard(isMobile),
            ),
          
          // Main Category Tab Bar
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: '🏆 Overall'),
                  Tab(text: '🎯 Trivia'),
                  Tab(text: '📝 BECE'),
                  Tab(text: '📚 WASSCE'),
                  Tab(text: '📖 Stories'),
                  Tab(text: '📕 Textbooks'),
                ],
                labelColor: const Color(0xFFD62828), // Uriel Red
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFFD62828),
                labelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          
          // Subcategory Tab Bar (for Trivia, BECE, WASSCE)
          if (_selectedCategory != 'Overall' && _selectedCategory != 'Stories' && _selectedCategory != 'Textbooks')
            SliverToBoxAdapter(
              child: Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TabBar(
                  controller: _categoryTabController,
                  isScrollable: true,
                  tabs: _getCurrentSubCategories().map((cat) => Tab(text: cat)).toList(),
                  labelColor: const Color(0xFF2ECC71), // Green
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFF2ECC71),
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          
          // Filters
          SliverToBoxAdapter(
            child: _buildFilters(isMobile),
          ),
          
          // Top 3 Podium
          SliverToBoxAdapter(
            child: _buildPodium(isMobile),
          ),
          
          // Leaderboard List
          SliverPadding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2ECC71),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < 3) return const SizedBox.shrink(); // Skip top 3
                        return _buildLeaderboardItem(
                          _leaderboardData[index],
                          isMobile,
                        );
                      },
                      childCount: _leaderboardData.length,
                    ),
                  ),
          ),
        ],
      );
    }
    
    // Standalone version with Scaffold and AppBar
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: CustomScrollView(
        slivers: [
          // App Bar with back button
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1A1E3F),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Hall of Fame',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareRank,
                tooltip: 'Share Your Rank',
              ),
            ],
          ),
          
          // Your Rank Card
          if (_currentUserEntry != null)
            SliverToBoxAdapter(
              child: _buildYourRankCard(isMobile),
            ),

          // Motivational Banner
          if (_motivationalMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildMotivationalBanner(isMobile),
            ),

          // Milestone Progress
          if (_milestoneMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildMilestoneCard(isMobile),
            ),
          
          // Main Category Tab Bar
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: '🏆 Overall'),
                  Tab(text: '🎯 Trivia'),
                  Tab(text: '📝 BECE'),
                  Tab(text: '📚 WASSCE'),
                  Tab(text: '📖 Stories'),
                  Tab(text: '📕 Textbooks'),
                ],
                labelColor: const Color(0xFFD62828),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFFD62828),
                labelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          
          // Subcategory Tab Bar (for Trivia, BECE, WASSCE)
          if (_selectedCategory != 'Overall' && _selectedCategory != 'Stories' && _selectedCategory != 'Textbooks')
            SliverToBoxAdapter(
              child: Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TabBar(
                  controller: _categoryTabController,
                  isScrollable: true,
                  tabs: _getCurrentSubCategories().map((cat) => Tab(text: cat)).toList(),
                  labelColor: const Color(0xFF2ECC71), // Green
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFF2ECC71),
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          
          // Filters
          SliverToBoxAdapter(
            child: _buildFilters(isMobile),
          ),
          
          // Top 3 Podium
          SliverToBoxAdapter(
            child: _buildPodium(isMobile),
          ),
          
          // Leaderboard List
          SliverPadding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            sliver: _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2ECC71),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < 3) return const SizedBox.shrink();
                        return _buildLeaderboardItem(
                          _leaderboardData[index],
                          isMobile,
                        );
                      },
                      childCount: _leaderboardData.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildYourRankCard(bool isMobile) {
    if (_currentUserEntry == null) return const SizedBox.shrink();
    
    final entry = _currentUserEntry!;
    
    return Column(
      children: [
        // Profile Card - Separate card with generic pet avatar
        Container(
          margin: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            12,
          ),
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getTierColor(entry.tier),
                _getTierColor(entry.tier).withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _getTierColor(entry.tier).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Generic Pet Avatar (Cat emoji as placeholder)
              Container(
                width: isMobile ? 80 : 100,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '🐱',
                    style: TextStyle(fontSize: isMobile ? 40 : 50),
                  ),
                ),
              ),
              
              SizedBox(width: isMobile ? 16 : 24),
              
              // Profile Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Rank',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '#${entry.rank}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 36 : 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.tier} Tier',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.xp} XP',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Share button
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 24),
                onPressed: _shareRank,
                tooltip: 'Share',
              ),
            ],
          ),
        ),
        
        // Stats Card - Separate card for performance metrics
        Container(
          margin: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            0,
            isMobile ? 16 : 24,
            12,
          ),
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Stats',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '${entry.questionsAnswered}',
                      'Questions\nSolved',
                      Icons.quiz_outlined,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '${entry.streak}',
                      'Day\nStreak',
                      Icons.local_fire_department_outlined,
                      const Color(0xFFFF6B35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '${entry.accuracy.toStringAsFixed(0)}%',
                      'Accuracy\nRate',
                      Icons.trending_up,
                      const Color(0xFF2ECC71),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '${(entry.questionsAnswered * 2 / 60).toStringAsFixed(1)}h',
                      'Time\nSpent',
                      Icons.access_time_outlined,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Second Card - Start Quiz (Accent Green)
        Container(
          margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71), // Accent Green
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Climb Higher?',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a quiz to earn more XP and improve your rank',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: widget.onStartQuiz ?? () {
                  // If no callback provided, just pop
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.play_arrow, color: Color(0xFF2ECC71)),
                label: Text(
                  'Start Quiz',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2ECC71),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalBanner(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1E3F), Color(0xFF2ECC71)], // Uriel Navy to Green
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _motivationalMessage,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(bool isMobile) {
    if (_xpToNextTier == 0) return const SizedBox.shrink();

    final progress = _currentUserEntry != null 
        ? (_currentUserEntry!.xp / (_currentUserEntry!.xp + _xpToNextTier))
        : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2ECC71), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Color(0xFF2ECC71), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _milestoneMessage,
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_xpToNextTier XP to next tier',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilters(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown('Period', _selectedPeriod, _periods, (value) {
              setState(() => _selectedPeriod = value!);
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown('Scope', _selectedScope, _scopes, (value) {
              setState(() => _selectedScope = value!);
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      style: GoogleFonts.montserrat(fontSize: 13, color: const Color(0xFF1A1E3F)),
    );
  }
  
  Widget _buildPodium(bool isMobile) {
    if (_leaderboardData.length < 3) return const SizedBox.shrink();
    
    final first = _leaderboardData[0];
    final second = _leaderboardData[1];
    final third = _leaderboardData[2];
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          _buildPodiumPosition(second, 2, 120, const Color(0xFFC0C0C0), '🥈'),
          const SizedBox(width: 16),
          // 1st place
          _buildPodiumPosition(first, 1, 160, const Color(0xFFFFD700), '🏆'),
          const SizedBox(width: 16),
          // 3rd place
          _buildPodiumPosition(third, 3, 100, const Color(0xFFCD7F32), '🥉'),
        ],
      ),
    );
  }
  
  Widget _buildPodiumPosition(LeaderboardEntry entry, int rank, double height, Color color, String emoji) {
    return Flexible(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              color: Colors.grey[300],
            ),
            child: entry.avatarUrl != null
                ? ClipOval(child: Image.network(entry.avatarUrl!, fit: BoxFit.cover))
                : Icon(Icons.person, size: 30, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          // Username - truncate on small screens
          Text(
            entry.username,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // XP
          Text(
            '${entry.xp} XP',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Podium
          Container(
            width: 80,
            height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
              Text(
                '#$rank',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
  
  Widget _buildLeaderboardItem(LeaderboardEntry entry, bool isMobile) {
    final isCurrentUser = entry.userId == FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? _getTierColor(entry.tier).withValues(alpha: 0.2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser 
            ? Border.all(color: _getTierColor(entry.tier), width: 2)
            : null,
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
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTierColor(entry.tier).withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: _getTierColor(entry.tier), width: 2),
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: entry.avatarUrl != null
                ? ClipOval(child: Image.network(entry.avatarUrl!, fit: BoxFit.cover))
                : Icon(Icons.person, size: 20, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD62828),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  entry.school,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // XP and Challenge button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.xp} XP',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getTierColor(entry.tier),
                ),
              ),
              Text(
                entry.tier,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              if (!isCurrentUser) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: () => _challengeUser(entry),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(60, 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Challenge',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _challengeUser(LeaderboardEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Challenge ${entry.username}',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Think you can beat ${entry.username}? Choose a quiz category to compete!',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildChallengeButton('🎯 Trivia', 'trivia'),
            const SizedBox(height: 12),
            _buildChallengeButton('📝 BECE Past Questions', 'bece'),
            const SizedBox(height: 12),
            _buildChallengeButton('📚 WASSCE Past Questions', 'wassce'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeButton(String label, String category) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Challenge sent! Complete a $category quiz to compete!',
                style: GoogleFonts.montserrat(),
              ),
              backgroundColor: const Color(0xFF2ECC71),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ECC71),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String school;
  final int xp;
  final String? avatarUrl;
  final int questionsAnswered;
  final double accuracy;
  final int streak;
  final String tier;
  
  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.school,
    required this.xp,
    this.avatarUrl,
    required this.questionsAnswered,
    required this.accuracy,
    required this.streak,
    required this.tier,
  });
}

class UserCategoryStats {
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  
  UserCategoryStats({
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
  });
}
