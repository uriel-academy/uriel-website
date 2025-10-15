import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../services/xp_service.dart';
import '../services/leaderboard_rank_service.dart';

/// Apple-inspired Leaderboard Page
/// Purpose: Motivate students through competitive learning and progress tracking
/// Design: Clean, minimal, data-driven with breathing space
class RedesignedLeaderboardPage extends StatefulWidget {
  const RedesignedLeaderboardPage({super.key});

  @override
  State<RedesignedLeaderboardPage> createState() => _RedesignedLeaderboardPageState();
}

class _RedesignedLeaderboardPageState extends State<RedesignedLeaderboardPage> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  String _selectedPeriod = 'All Time';
  
  // Data
  List<LeaderboardUser> _topUsers = [];
  LeaderboardUser? _currentUser;
  bool _isLoading = true;
  
  // Listen to Firestore changes for profile picture updates
  Stream<DocumentSnapshot>? _userDocStream;
  
  // Categories with their emoji icons
  final List<Map<String, String>> _categories = [
    {'id': 'overall', 'name': 'Overall', 'emoji': '🏆'},
    {'id': 'trivia', 'name': 'Trivia', 'emoji': '🎯'},
    {'id': 'bece', 'name': 'BECE', 'emoji': '📝'},
    {'id': 'wassce', 'name': 'WASSCE', 'emoji': '📚'},
    {'id': 'courses', 'name': 'Courses', 'emoji': '📖'},
  ];
  
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'School', 'All Time'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadLeaderboardData();
      }
    });
    
    // Listen to current user's Firestore document changes (for preset avatar, profileImageUrl)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
      
      _userDocStream!.listen((snapshot) {
        if (snapshot.exists && mounted) {
          debugPrint('🔄 User Firestore data changed, reloading leaderboard');
          _loadLeaderboardData();
        }
      });
    }
    
    _loadLeaderboardData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  String get _selectedCategory => _categories[_tabController.index]['id']!;
  
  Future<void> _loadLeaderboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Get top 20 users ordered by XP (including 0 XP users)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalXP', descending: true)
          .limit(20)
          .get();
      
      List<LeaderboardUser> users = [];
      int rank = 1;
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        
        // Calculate category-specific stats
        final stats = await _getCategoryStats(userId, _selectedCategory);
        
        // Get display name - use Firebase Auth displayName for current user
        String displayName = data['displayName'] ?? '';
        if (displayName.isEmpty && userId == user.uid) {
          displayName = user.displayName ?? user.email?.split('@')[0] ?? 'You';
        }
        if (displayName.isEmpty) {
          // Try to get from Firebase Auth if available, otherwise use email prefix
          displayName = data['email']?.split('@')[0] ?? 'Student $rank';
        }
        
        // Get photo URL - prioritize Firestore profileImageUrl > Firebase Auth photoURL
        String? photoURL = data['profileImageUrl'] as String?;
        if (photoURL == null || photoURL.isEmpty) {
          photoURL = data['photoURL'] as String?; // Fallback to old field
        }
        if ((photoURL == null || photoURL.isEmpty) && userId == user.uid) {
          photoURL = user.photoURL; // Fallback to Firebase Auth for current user
        }
        
        // Get previous rank from user data (stored from last leaderboard update)
        final previousRank = data['previousRank'] as int?;
        int? rankChange;
        if (previousRank != null) {
          rankChange = previousRank - rank; // Positive = moved up, Negative = moved down
        }
        
        final leaderboardUser = LeaderboardUser(
          rank: rank,
          userId: userId,
          displayName: displayName,
          school: data['school'] ?? 'Ghana School',
          totalXP: (data['totalXP'] as int?) ?? 0,
          categoryXP: stats['xp'] ?? 0,
          photoURL: photoURL,
          presetAvatar: data['presetAvatar'],
          questionsAnswered: stats['questions'] ?? 0,
          correctAnswers: stats['correct'] ?? 0,
          dailyStreak: (data['currentStreak'] as int?) ?? 0,
          completedCourses: stats['completedCourses'] ?? 0,
          rankChange: rankChange,
        );
        
        users.add(leaderboardUser);
        
        if (userId == user.uid) {
          _currentUser = leaderboardUser;
        }
        
        rank++;
      }
      
      // If current user not in top 20, find their actual rank
      if (_currentUser == null) {
        // Count how many users have more XP than current user
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final userXP = (data['totalXP'] as int?) ?? 0;
          
          // Get actual rank by counting users with more XP
          final higherRankCount = await FirebaseFirestore.instance
              .collection('users')
              .where('totalXP', isGreaterThan: userXP)
              .count()
              .get();
          
          final actualRank = higherRankCount.count! + 1;
          final stats = await _getCategoryStats(user.uid, _selectedCategory);
          
          // Get display name from Firebase Auth if not in Firestore
          String displayName = data['displayName'] ?? '';
          if (displayName.isEmpty) {
            displayName = user.displayName ?? user.email?.split('@')[0] ?? 'You';
          }
          
          // Get photo URL - prioritize Firestore profileImageUrl > Firebase Auth photoURL
          String? photoURL = data['profileImageUrl'] as String?;
          if (photoURL == null || photoURL.isEmpty) {
            photoURL = data['photoURL'] as String?; // Fallback to old field
          }
          if (photoURL == null || photoURL.isEmpty) {
            photoURL = user.photoURL; // Fallback to Firebase Auth photo
          }
          
          // Get previous rank
          final previousRank = data['previousRank'] as int?;
          int? rankChange;
          if (previousRank != null) {
            rankChange = previousRank - actualRank;
          }
          
          _currentUser = LeaderboardUser(
            rank: actualRank,
            userId: user.uid,
            displayName: displayName,
            school: data['school'] ?? 'My School',
            totalXP: userXP,
            categoryXP: stats['xp'] ?? 0,
            photoURL: photoURL,
            presetAvatar: data['presetAvatar'],
            questionsAnswered: stats['questions'] ?? 0,
            correctAnswers: stats['correct'] ?? 0,
            dailyStreak: (data['currentStreak'] as int?) ?? 0,
            completedCourses: stats['completedCourses'] ?? 0,
            rankChange: rankChange,
          );
        }
      }
      
      _topUsers = users;
      
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<Map<String, int>> _getCategoryStats(String userId, String category) async {
    try {
      // Handle courses separately (uses lesson_progress)
      if (category == 'courses') {
        // Query without the problematic index - just use userId filter
        final progressSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('lesson_progress')
            .where('completed', isEqualTo: true)
            .get();
        
        int totalXP = 0;
        for (var doc in progressSnapshot.docs) {
          totalXP += (doc.data()['xpEarned'] as int?) ?? 0;
        }
        
        return {
          'xp': totalXP,
          'questions': progressSnapshot.size,
          'correct': progressSnapshot.size,
          'completedCourses': 0,
        };
      }
      
      // Query quizzes collection for quiz-based categories
      var query = FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId);
      
      // Filter by category (overall = all quizzes, no filter)
      // Note: Firestore stores BECE/WASSCE in uppercase, trivia in lowercase
      if (category == 'trivia') {
        query = query.where('quizType', isEqualTo: 'trivia');
      } else if (category == 'bece') {
        query = query.where('quizType', isEqualTo: 'BECE'); // Uppercase in Firestore
      } else if (category == 'wassce') {
        query = query.where('quizType', isEqualTo: 'WASSCE'); // Uppercase in Firestore
      }
      // If category == 'overall', don't add any quizType filter
      
      final snapshot = await query.get();
      
      debugPrint('Category: $category, Found ${snapshot.size} quizzes for user $userId');
      
      int totalXP = 0;
      int totalQuestions = 0;
      int totalCorrect = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('Quiz doc: ${doc.id}, quizType: ${data['quizType']}, questions: ${data['totalQuestions']}, correct: ${data['correctAnswers']}');
        totalXP += (data['xpEarned'] as int?) ?? 0;
        totalQuestions += (data['totalQuestions'] as int?) ?? 0;
        totalCorrect += (data['correctAnswers'] as int?) ?? 0;
      }
      
      debugPrint('Category $category totals - XP: $totalXP, Questions: $totalQuestions, Correct: $totalCorrect');
      
      return {
        'xp': totalXP,
        'questions': totalQuestions,
        'correct': totalCorrect,
        'completedCourses': 0,
      };
      
    } catch (e) {
      debugPrint('Error getting category stats: $e');
      return {'xp': 0, 'questions': 0, 'correct': 0, 'completedCourses': 0};
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 768;
    
    return Container(
      color: const Color(0xFFFAFAFA), // Apple-style light background
      child: CustomScrollView(
        slivers: [
          // Hero Section - User's Current Standing
          _buildHeroSection(isSmallScreen),
          
          // Category Tabs
          _buildCategoryTabs(),
          
          // Quick Stats Overview
          if (_currentUser != null)
            _buildQuickStats(isSmallScreen),
          
          // EPL-Style Table Header with Period Filter
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                isSmallScreen ? 16 : 24,
                24,
                isSmallScreen ? 16 : 24,
                0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header with Title and Filter
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Top Learners',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        // Period Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            underline: const SizedBox(),
                            isDense: true,
                            items: _periods.map((period) {
                              return DropdownMenuItem(
                                value: period,
                                child: Text(
                                  period,
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPeriod = value!);
                              _loadLeaderboardData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table Column Headers (EPL Style)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 16,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F2F7),
                      border: Border(
                        top: BorderSide(color: Color(0xFFE5E5EA), width: 1),
                        bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Position
                        SizedBox(
                          width: isSmallScreen ? 30 : 40,
                          child: Text(
                            '#',
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E8E93),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 12),
                        // Change indicator space
                        SizedBox(width: isSmallScreen ? 16 : 20),
                        SizedBox(width: isSmallScreen ? 6 : 12),
                        // Avatar + Name
                        Expanded(
                          flex: isSmallScreen ? 3 : 4,
                          child: Text(
                            'LEARNER',
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Rank/Tier (hide on mobile)
                        if (!isSmallScreen) ...[
                          SizedBox(
                            width: 80,
                            child: Text(
                              'RANK',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        // Questions (hide on mobile)
                        if (!isSmallScreen) ...[
                          SizedBox(
                            width: 45,
                            child: Text(
                              'Q',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        // XP Points
                        SizedBox(
                          width: isSmallScreen ? 50 : 70,
                          child: Text(
                            'XP',
                            style: GoogleFonts.inter(
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8E8E93),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Rankings Table Body - All Ranks from 1-20
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD2B48C),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 16 : 24,
                0,
                isSmallScreen ? 16 : 24,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= _topUsers.length) {
                      // After top 20, show current user if they're not in top 20
                      if (_currentUser != null && _currentUser!.rank > 20) {
                        if (index == _topUsers.length) {
                          // Show separator
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: Color(0xFFD1D1D6), thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'YOUR POSITION',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF8E8E93),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Color(0xFFD1D1D6), thickness: 1)),
                              ],
                            ),
                          );
                        } else if (index == _topUsers.length + 1) {
                          return _buildRankingRow(_currentUser!, isSmallScreen);
                        }
                      }
                      return null;
                    }
                    
                    return _buildRankingRow(_topUsers[index], isSmallScreen);
                  },
                  childCount: _topUsers.length + 
                      (_currentUser != null && _currentUser!.rank > 20 ? 2 : 0),
                ),
              ),
            ),
          
          // Table Bottom Border
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              height: 1,
            ),
          ),
          
          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeroSection(bool isSmallScreen) {
    if (_currentUser == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    
    final user = _currentUser!;
    
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
        decoration: BoxDecoration(
          color: const Color(0xFFD2B48C), // Solid Beige
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD2B48C).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // User Avatar with Rank Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: FutureBuilder<LeaderboardRank?>(
                              future: LeaderboardRankService().getUserRank(user.totalXP),
                              builder: (context, snapshot) {
                                if (snapshot.data?.imageUrl != null) {
                                  return ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: snapshot.data!.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 35),
                                    ),
                                  );
                                }
                                return const Icon(Icons.person, size: 35, color: Color(0xFF8E8E93));
                              },
                            ),
                          ),
                          // Rank Number Badge
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759), // iOS Green
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                '#${user.rank}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // User Info - Position, Name, Points
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Position Indicator
                            Row(
                              children: [
                                Text(
                                  'Position #${user.rank}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.85),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (user.rankChange != null && user.rankChange != 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: user.rankChange! > 0 
                                          ? const Color(0xFF34C759).withOpacity(0.3)
                                          : const Color(0xFFFF3B30).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          user.rankChange! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${user.rankChange!.abs()}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Name
                            Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Accumulated Points
                            Text(
                              '${user.totalXP} XP Accumulated',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Share Button
                      IconButton(
                        onPressed: () => _shareRank(user),
                        icon: const Icon(Icons.ios_share, color: Colors.white),
                        tooltip: 'Share',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // XP Progress to Next Rank
                  FutureBuilder<LeaderboardRank?>(
                    future: LeaderboardRankService().getNextRank(user.totalXP),
                    builder: (context, snapshot) {
                      if (snapshot.data != null) {
                        final nextRank = snapshot.data!;
                        final xpNeeded = nextRank.minXP - user.totalXP;
                        final progress = user.totalXP / nextRank.minXP;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${user.totalXP} XP',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$xpNeeded XP to ${nextRank.name}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 12,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF34C759), // iOS Green
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return Text(
                        '${user.totalXP} XP • Max Rank Achieved 🏆',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryTabs() {
    return SliverToBoxAdapter(
      child: Container(
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicator: BoxDecoration(
            color: const Color(0xFFD2B48C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          labelColor: const Color(0xFFD2B48C),
          unselectedLabelColor: const Color(0xFF8E8E93),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: _categories.map((cat) {
            return Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat['emoji']!),
                    const SizedBox(width: 6),
                    Text(cat['name']!),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  Widget _buildQuickStats(bool isSmallScreen) {
    final user = _currentUser!;
    
    return SliverToBoxAdapter(
      child: FutureBuilder<Map<String, int>>(
        future: _getCategoryStats(user.userId, _selectedCategory),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              margin: EdgeInsets.fromLTRB(
                isSmallScreen ? 16 : 24,
                8,
                isSmallScreen ? 16 : 24,
                16,
              ),
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFD2B48C))),
            );
          }
          
          final stats = snapshot.data!;
          final questions = stats['questions'] ?? 0;
          final correct = stats['correct'] ?? 0;
          final accuracy = questions > 0 ? (correct / questions * 100) : 0.0;
          
          return Container(
            margin: EdgeInsets.fromLTRB(
              isSmallScreen ? 16 : 24,
              8,
              isSmallScreen ? 16 : 24,
              16,
            ),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Performance',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                      '$questions',
                      'Questions',
                      Icons.quiz_outlined,
                      const Color(0xFFD2B48C),
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      '${accuracy.toStringAsFixed(0)}%',
                      'Accuracy',
                      Icons.trending_up,
                      const Color(0xFF34C759),
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      '${user.dailyStreak}',
                      'Day Streak',
                      Icons.local_fire_department,
                      const Color(0xFFFF9500),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatChip(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF8E8E93),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRankingRow(LeaderboardUser user, bool isSmallScreen) {
    final isCurrentUser = user.userId == FirebaseAuth.instance.currentUser?.uid;
    
    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? const Color(0xFFD2B48C).withOpacity(0.12) 
            : Colors.white,
        border: Border(
          left: isCurrentUser 
              ? const BorderSide(color: Color(0xFFD2B48C), width: 4)
              : BorderSide.none,
          bottom: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !isCurrentUser ? () => _showUserProfile(user) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            child: Row(
              children: [
                // Position Number
                SizedBox(
                  width: isSmallScreen ? 30 : 40,
                  child: Text(
                    '${user.rank}',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser ? const Color(0xFFD2B48C) : const Color(0xFF3C3C43),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                SizedBox(width: isSmallScreen ? 6 : 12),
                
                // Rank Change Indicator
                SizedBox(
                  width: isSmallScreen ? 16 : 20,
                  child: user.rankChange != null && user.rankChange != 0
                      ? Icon(
                          user.rankChange! > 0 
                              ? Icons.arrow_drop_up 
                              : Icons.arrow_drop_down,
                          size: isSmallScreen ? 18 : 20,
                          color: user.rankChange! > 0 
                              ? const Color(0xFF34C759) 
                              : const Color(0xFFFF3B30),
                        )
                      : Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD1D1D6),
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                
                SizedBox(width: isSmallScreen ? 6 : 12),
                
                // User Avatar (Profile Picture, NOT rank badge)
                Container(
                  width: isSmallScreen ? 32 : 40,
                  height: isSmallScreen ? 32 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF2F2F7),
                    border: Border.all(
                      color: isCurrentUser ? const Color(0xFFD2B48C) : const Color(0xFFE5E5EA),
                      width: isSmallScreen ? 1.5 : 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _buildAvatarImage(user, isSmallScreen),
                  ),
                ),
                
                SizedBox(width: isSmallScreen ? 8 : 12),
                
                // User Name & School
                Expanded(
                  flex: isSmallScreen ? 3 : 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1C1C1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD2B48C),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'YOU',
                                style: GoogleFonts.inter(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isSmallScreen) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.school,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF8E8E93),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Rank/Tier Name (hide on very small screens)
                if (!isSmallScreen) ...[
                  SizedBox(
                    width: 80,
                    child: FutureBuilder<LeaderboardRank?>(
                      future: LeaderboardRankService().getUserRank(user.totalXP),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data?.name ?? 'Learner',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF5856D6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Questions Answered (hide on very small screens)
                if (!isSmallScreen) ...[
                  SizedBox(
                    width: 45,
                    child: Text(
                      user.questionsAnswered > 0 ? '${user.questionsAnswered}' : '-',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF3C3C43),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // XP Score
                SizedBox(
                  width: isSmallScreen ? 50 : 70,
                  child: Text(
                    '${user.totalXP}',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD2B48C),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showUserProfile(LeaderboardUser user) {
    final accuracy = user.questionsAnswered > 0
        ? (user.correctAnswers / user.questionsAnswered * 100)
        : 0.0;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // User Avatar
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF2F2F7),
              ),
              child: FutureBuilder<LeaderboardRank?>(
                future: LeaderboardRankService().getUserRank(user.totalXP),
                builder: (context, snapshot) {
                  if (snapshot.data?.imageUrl != null) {
                    return ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: snapshot.data!.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 40),
                      ),
                    );
                  }
                  return const Icon(Icons.person, size: 40, color: Color(0xFF8E8E93));
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User Name
            Text(
              user.displayName,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // School & Rank
            FutureBuilder<LeaderboardRank?>(
              future: LeaderboardRankService().getUserRank(user.totalXP),
              builder: (context, snapshot) {
                return Text(
                  '${user.school} • ${snapshot.data?.name ?? "Learner"}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF8E8E93),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Stats Grid
            Row(
              children: [
                _buildProfileStat('${user.totalXP}', 'Total XP', Icons.star),
                _buildProfileStat('#${user.rank}', 'Rank', Icons.emoji_events),
                _buildProfileStat('${accuracy.toStringAsFixed(0)}%', 'Accuracy', Icons.trending_up),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Challenge Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _challengeUser(user);
                },
                icon: const Icon(Icons.bolt, size: 20),
                label: Text(
                  'Challenge ${user.displayName.split(' ').first}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2B48C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileStat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFD2B48C)),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF8E8E93),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _challengeUser(LeaderboardUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '⚔️ Challenge ${user.displayName}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: Text(
          'Choose a category to compete in:',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '🎯 Challenge sent! Complete a quiz to compete with ${user.displayName}',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(0xFF34C759),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD2B48C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Start Challenge', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
  
  /// Build avatar image supporting both preset avatars and network images
  Widget _buildAvatarImage(LeaderboardUser user, bool isSmallScreen) {
    // Priority: presetAvatar (asset) > photoURL (network) > default icon
    if (user.presetAvatar != null && user.presetAvatar!.isNotEmpty) {
      // Preset avatar from assets
      return Image.asset(
        user.presetAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.person, 
            size: isSmallScreen ? 16 : 20, 
            color: const Color(0xFF8E8E93),
          );
        },
      );
    } else if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      // Network image (Firebase Auth photoURL or Firestore profileImageUrl)
      return CachedNetworkImage(
        imageUrl: user.photoURL!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Icon(
          Icons.person, 
          size: isSmallScreen ? 16 : 20, 
          color: const Color(0xFF8E8E93),
        ),
        errorWidget: (context, url, error) => Icon(
          Icons.person, 
          size: isSmallScreen ? 16 : 20, 
          color: const Color(0xFF8E8E93),
        ),
      );
    } else {
      // Default icon
      return Icon(
        Icons.person, 
        size: isSmallScreen ? 16 : 20, 
        color: const Color(0xFF8E8E93),
      );
    }
  }
  
  void _shareRank(LeaderboardUser user) {
    final message = '''🏆 I'm ranked #${user.rank} on Uriel Academy with ${user.totalXP} XP!

Think you can beat me? 💪
Join the challenge 👉 https://uriel.academy

#UrielAcademy #LearnPracticeSucceed''';
    
    Share.share(message);
  }
}

/// Data Model for Leaderboard Users
class LeaderboardUser {
  final int rank;
  final String userId;
  final String displayName;
  final String school;
  final int totalXP;
  final int categoryXP;
  final String? photoURL;
  final String? presetAvatar;
  final int questionsAnswered;
  final int correctAnswers;
  final int dailyStreak;
  final int completedCourses;
  final int? rankChange; // Positive = moved up, Negative = moved down, 0 = no change, null = new
  
  LeaderboardUser({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.school,
    required this.totalXP,
    required this.categoryXP,
    this.photoURL,
    this.presetAvatar,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.dailyStreak,
    required this.completedCourses,
    this.rankChange,
  });
}
