import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trivia_model.dart';
import '../services/trivia_service.dart';

class TriviaPage extends StatefulWidget {
  const TriviaPage({super.key});

  @override
  State<TriviaPage> createState() => _TriviaPageState();
}

class _TriviaPageState extends State<TriviaPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  final TriviaService _triviaService = TriviaService();
  final TextEditingController _searchController = TextEditingController();

  String selectedCategory = 'All';
  String selectedDifficulty = 'All';
  String selectedGameMode = 'All';
  String searchQuery = '';

  List<TriviaChallenge> allChallenges = [];
  List<TriviaChallenge> filteredChallenges = [];
  bool isLoading = true;

  final List<String> categories = [
    'All', 'Mathematics', 'English', 'Science', 'Social Studies',
    'History', 'Geography', 'Literature', 'General Knowledge',
    'Sports', 'Technology', 'Arts & Culture'
  ];
  final List<String> difficulties = ['All', 'Easy', 'Medium', 'Hard', 'Expert'];
  final List<String> gameModes = ['All', 'Quick Play', 'Tournament', 'Daily Challenge', 'Multiplayer'];

  // User stats
  int totalPoints = 2450;
  int rank = 15;
  int streak = 7;
  int weeklyPoints = 340;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: 4, vsync: this);
    
    _loadTriviaChallenges();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTriviaChallenges() async {
    try {
      setState(() => isLoading = true);
      allChallenges = await _triviaService.getTriviaChallenges();
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading trivia challenges: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredChallenges = allChallenges.where((challenge) {
        final matchesCategory = selectedCategory == 'All' || challenge.category == selectedCategory;
        final matchesDifficulty = selectedDifficulty == 'All' || challenge.difficulty == selectedDifficulty;
        final matchesGameMode = selectedGameMode == 'All' || challenge.gameMode == selectedGameMode;
        final matchesSearch = searchQuery.isEmpty ||
            challenge.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            challenge.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
            challenge.description.toLowerCase().contains(searchQuery.toLowerCase());

        return matchesCategory && matchesDifficulty && matchesGameMode && matchesSearch;
      }).toList();

      // Sort by relevance and popularity
      filteredChallenges.sort((a, b) {
        if (a.isNew && !b.isNew) return -1;
        if (!a.isNew && b.isNew) return 1;
        return b.participants.compareTo(a.participants);
      });
    });
  }

  void _resetFilters() {
    setState(() {
      selectedCategory = 'All';
      selectedDifficulty = 'All';
      selectedGameMode = 'All';
      searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: isMobile ? 100 : 120,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1E3F),
              title: Text(
                'Learning Trivia',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              centerTitle: false,
              titleSpacing: isMobile ? 16 : 24,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8FAFE)],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.leaderboard),
                  onPressed: () => _showLeaderboard(),
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => _showGameHistory(),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // User Stats Card
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _buildUserStatsCard(isMobile),
              ),
            ),

            // Search and Filters
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Search trivia challenges, topics...',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => searchQuery = '');
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                          _applyFilters();
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Filter Chips
                    if (isMobile) ...[
                      _buildMobileFilters(),
                    ] else ...[
                      _buildDesktopFilters(),
                    ],

                    // Filter Summary and Clear
                    if (_hasActiveFilters()) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.filter_list, 
                              size: 16, 
                              color: const Color(0xFFD62828)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${filteredChallenges.length} challenges found',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: const Color(0xFF1A1E3F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear Filters'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD62828),
                              textStyle: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Quick Access Tabs
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabs: const [
                    Tab(text: 'All Games'),
                    Tab(text: 'Quick Play'),
                    Tab(text: 'Tournaments'),
                    Tab(text: 'Daily'),
                  ],
                  labelColor: const Color(0xFFD62828),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFFD62828),
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            // Featured Challenge
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _buildFeaturedChallenge(isMobile),
              ),
            ),

            // Content
            if (isLoading) ...[
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading trivia challenges...',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (filteredChallenges.isEmpty) ...[
              SliverFillRemaining(
                child: _buildEmptyState(),
              ),
            ] else ...[
              SliverPadding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                sliver: _buildChallengesList(isMobile),
              ),
            ],

            // Bottom padding for mobile
            if (isMobile) ...[
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startQuickPlay(),
        backgroundColor: const Color(0xFFD62828),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.flash_on),
        label: Text(
          'Quick Play',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildUserStatsCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE91E63), Color(0xFFD62828)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.3),
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
              Icon(Icons.psychology, color: Colors.white, size: isMobile ? 24 : 28),
              const SizedBox(width: 12),
              Text(
                'Your Trivia Stats',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, 
                         color: Colors.white, 
                         size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            // Mobile: 2x2 grid
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Points', '$totalPoints', Icons.stars)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Rank', '#$rank', Icons.emoji_events)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Streak', '$streak days', Icons.local_fire_department)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('This Week', '$weeklyPoints pts', Icons.trending_up)),
              ],
            ),
          ] else ...[
            // Desktop: horizontal row
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Points', '$totalPoints', Icons.stars)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Global Rank', '#$rank', Icons.emoji_events)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Streak', '$streak days', Icons.local_fire_department)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('This Week', '$weeklyPoints pts', Icons.trending_up)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        // Category and Difficulty filters
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                'Category',
                selectedCategory,
                categories,
                (value) => setState(() {
                  selectedCategory = value!;
                  _applyFilters();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown(
                'Difficulty',
                selectedDifficulty,
                difficulties,
                (value) => setState(() {
                  selectedDifficulty = value!;
                  _applyFilters();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Game Mode filter
        _buildFilterDropdown(
          'Game Mode',
          selectedGameMode,
          gameModes,
          (value) => setState(() {
            selectedGameMode = value!;
            _applyFilters();
          }),
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            'Category',
            selectedCategory,
            categories,
            (value) => setState(() {
              selectedCategory = value!;
              _applyFilters();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Difficulty',
            selectedDifficulty,
            difficulties,
            (value) => setState(() {
              selectedDifficulty = value!;
              _applyFilters();
            }),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            'Game Mode',
            selectedGameMode,
            gameModes,
            (value) => setState(() {
              selectedGameMode = value!;
              _applyFilters();
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          style: GoogleFonts.montserrat(
            color: const Color(0xFF1A1E3F),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFeaturedChallenge(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1E3F).withOpacity(0.3),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Featured Challenge',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NEW',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ghana Independence Day Quiz',
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Test your knowledge about Ghana\'s journey to independence with this special challenge featuring 20 questions about our nation\'s history.',
            style: GoogleFonts.montserrat(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            Row(
              children: [
                _buildChallengeInfo(Icons.timer, '15 min'),
                const SizedBox(width: 16),
                _buildChallengeInfo(Icons.quiz, '20 Qs'),
                const SizedBox(width: 16),
                _buildChallengeInfo(Icons.star, '500 pts'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startFeaturedChallenge(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                _buildChallengeInfo(Icons.timer, '15 minutes'),
                const SizedBox(width: 24),
                _buildChallengeInfo(Icons.quiz, '20 Questions'),
                const SizedBox(width: 24),
                _buildChallengeInfo(Icons.star, '500 Points'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _startFeaturedChallenge(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.montserrat(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return selectedCategory != 'All' ||
        selectedDifficulty != 'All' ||
        selectedGameMode != 'All' ||
        searchQuery.isNotEmpty;
  }

  Widget _buildChallengesList(bool isMobile) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        childAspectRatio: isMobile ? 1.2 : 1.4,
        crossAxisSpacing: isMobile ? 0 : 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final challenge = filteredChallenges[index];
          return _buildChallengeCard(challenge, isMobile);
        },
        childCount: filteredChallenges.length,
      ),
    );
  }

  Widget _buildChallengeCard(TriviaChallenge challenge, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _playChallenge(challenge),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getCategoryColor(challenge.category).withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(challenge.category),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(challenge.category),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.category,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: _getCategoryColor(challenge.category),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          challenge.gameMode,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (challenge.isNew) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD62828),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Title and Description
              Text(
                challenge.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                challenge.description,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Challenge Info
              Row(
                children: [
                  _buildInfoChip(Icons.timer, '${challenge.timeLimit}m', Colors.orange),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.quiz, '${challenge.questionCount}Q', Colors.blue),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.star, '${challenge.points}pts', Colors.amber),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Difficulty and Participants
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(challenge.difficulty).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      challenge.difficulty,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyColor(challenge.difficulty),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.people, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${challenge.participants}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Play Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _playChallenge(challenge),
                  icon: Icon(
                    challenge.gameMode == 'Multiplayer' ? Icons.group : Icons.play_arrow,
                    size: 16,
                  ),
                  label: Text(
                    challenge.gameMode == 'Multiplayer' ? 'Join Game' : 'Play Now',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getCategoryColor(challenge.category),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No trivia challenges found',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'No challenges match your search criteria.\nTry adjusting your filters or search terms.'
                  : 'No trivia challenges available for the selected filters.\nTry selecting different options.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF2196F3);
      case 'english':
        return const Color(0xFF4CAF50);
      case 'science':
        return const Color(0xFFFF9800);
      case 'social studies':
        return const Color(0xFF9C27B0);
      case 'history':
        return const Color(0xFF795548);
      case 'geography':
        return const Color(0xFF009688);
      case 'literature':
        return const Color(0xFF3F51B5);
      case 'general knowledge':
        return const Color(0xFF607D8B);
      case 'sports':
        return const Color(0xFF8BC34A);
      case 'technology':
        return const Color(0xFF9E9E9E);
      case 'arts & culture':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF1A1E3F);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate;
      case 'english':
        return Icons.menu_book;
      case 'science':
        return Icons.science;
      case 'social studies':
        return Icons.public;
      case 'history':
        return Icons.history_edu;
      case 'geography':
        return Icons.map;
      case 'literature':
        return Icons.library_books;
      case 'general knowledge':
        return Icons.lightbulb;
      case 'sports':
        return Icons.sports;
      case 'technology':
        return Icons.computer;
      case 'arts & culture':
        return Icons.palette;
      default:
        return Icons.psychology;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFF9800);
      case 'hard':
        return const Color(0xFFFF5722);
      case 'expert':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF607D8B);
    }
  }

  void _playChallenge(TriviaChallenge challenge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          challenge.title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${challenge.category}'),
            Text('Duration: ${challenge.timeLimit} minutes'),
            Text('Questions: ${challenge.questionCount}'),
            Text('Points: ${challenge.points}'),
            Text('Difficulty: ${challenge.difficulty}'),
            const SizedBox(height: 16),
            Text(
              challenge.description,
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you ready to start this challenge?',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting ${challenge.title}...'),
                  backgroundColor: const Color(0xFF1A1E3F),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getCategoryColor(challenge.category),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _startQuickPlay() {
    // TODO: Start quick play mode
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quick Play mode coming soon!'),
        backgroundColor: Color(0xFF1A1E3F),
      ),
    );
  }

  void _startFeaturedChallenge() {
    // TODO: Start featured challenge
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting featured challenge...'),
        backgroundColor: Color(0xFF1A1E3F),
      ),
    );
  }

  void _showLeaderboard() {
    // TODO: Show leaderboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Leaderboard coming soon!'),
        backgroundColor: Color(0xFF1A1E3F),
      ),
    );
  }

  void _showGameHistory() {
    // TODO: Show game history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game history coming soon!'),
        backgroundColor: Color(0xFF1A1E3F),
      ),
    );
  }
}
