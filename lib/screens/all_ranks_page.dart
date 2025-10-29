import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_rank_service.dart';
import '../widgets/rank_badge_widget.dart';

class AllRanksPage extends StatefulWidget {
  final int? userXP;

  const AllRanksPage({super.key, this.userXP});

  @override
  State<AllRanksPage> createState() => _AllRanksPageState();
}

class _AllRanksPageState extends State<AllRanksPage> with SingleTickerProviderStateMixin {
  final LeaderboardRankService _rankService = LeaderboardRankService();
  List<LeaderboardRank> _allRanks = [];
  LeaderboardRank? _userCurrentRank;
  bool _isLoading = true;
  late TabController _tabController;
  
  final List<String> _tiers = ['All', 'Beginner', 'Achiever', 'Advanced', 'Expert', 'Prestige', 'Supreme'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tiers.length, vsync: this);
    _loadRanks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    setState(() => _isLoading = true);
    
    try {
      final ranks = await _rankService.getAllRanks();
      
      LeaderboardRank? currentRank;
      if (widget.userXP != null) {
        currentRank = await _rankService.getUserRank(widget.userXP!);
      }
      
      setState(() {
        _allRanks = ranks;
        _userCurrentRank = currentRank;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading ranks: $e');
      setState(() => _isLoading = false);
    }
  }

  List<LeaderboardRank> _getFilteredRanks(String tier) {
    if (tier == 'All') return _allRanks;
    return _allRanks.where((rank) => rank.tier == tier).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        title: Text(
          'Leaderboard Ranks',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1E3F)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFD62828),
              labelColor: const Color(0xFFD62828),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: _tiers.map((tier) => Tab(text: tier)).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Quote at the top
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 24 : 64,
                    vertical: isSmallScreen ? 32 : 48,
                  ),
                  child: Text(
                    '"Ranks in Uriel aren\'t about competition. They\'re about growth. Every learner\'s path is unique, but the journey is shared."',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 16 : 20,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6E6E73),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Existing TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tiers.map((tier) => _buildRanksList(tier, isSmallScreen)).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRanksList(String tier, bool isSmallScreen) {
    final filteredRanks = _getFilteredRanks(tier);

    if (filteredRanks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No ranks found',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      children: [
        // Tier Header (if not "All")
        if (tier != 'All') ...[
          _buildTierHeader(tier),
          const SizedBox(height: 24),
        ],

        // Current Rank Highlight
        if (_userCurrentRank != null && 
            (tier == 'All' || _userCurrentRank!.tier == tier)) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _userCurrentRank!.getTierColor(),
                  _userCurrentRank!.getTierColor().withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _userCurrentRank!.color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                RankBadgeWidget(
                  rank: _userCurrentRank!,
                  size: 60,
                  showLabel: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Current Rank',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _userCurrentRank!.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_rankService.formatXP(widget.userXP!)} XP',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // XP Economy Table
        _buildXPEconomyTable(isSmallScreen),

        // Rank List
        ...filteredRanks.map((rank) {
          final isCurrentRank = _userCurrentRank?.rank == rank.rank;
          final isLocked = widget.userXP != null && widget.userXP! < rank.minXP;

          return RankListTile(
            rank: rank,
            isCurrentRank: isCurrentRank,
            isLocked: isLocked,
            onTap: () => _showRankDetails(rank),
          );
        }),

        // Bottom spacing
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildXPEconomyTable(bool isSmallScreen) {
    final xpData = [
      {'action': 'Daily login', 'reward': '50 XP', 'notes': ''},
      {'action': 'Completing a quiz (40 questions)', 'reward': '200 XP', 'notes': '5 XP per question + completion bonus'},
      {'action': 'Perfect quiz score (≥90%)', 'reward': '+100 XP bonus', 'notes': ''},
      {'action': 'Uploading notes', 'reward': '150 XP', 'notes': ''},
      {'action': 'Receiving upvotes/downloads on notes', 'reward': '+10 XP per upvote', 'notes': ''},
      {'action': 'Completing AI Revision Plan', 'reward': '500 XP', 'notes': ''},
      {'action': 'Maintaining 7-day streak', 'reward': '+300 XP bonus', 'notes': ''},
      {'action': 'Achieving new badge', 'reward': '250–500 XP', 'notes': ''},
      {'action': 'Finishing a full subject module', 'reward': '1000–2000 XP', 'notes': ''},
      {'action': 'Monthly contest (winner)', 'reward': '5000 XP', 'notes': ''},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📈 XP Economy',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(width: 8),
              if (!isSmallScreen)
                Text(
                  'How you earn XP',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Action',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'XP Reward',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Notes',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Table Rows
          ...xpData.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    item['action']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    item['reward']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD62828),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    item['notes']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTierHeader(String tier) {
    final tierInfo = _getTierInfo(tier);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierInfo['color'] as Color,
            (tierInfo['color'] as Color).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tierInfo['icon'] as IconData,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                '$tier Tier',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tierInfo['theme'] as String,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tierInfo['description'] as String,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTierInfo(String tier) {
    final tierData = {
      'Beginner': {
        'theme': 'Discovery & Curiosity',
        'description': 'Every great learner starts with a single question.',
        'color': const Color(0xFF4CAF50),
        'icon': Icons.emoji_events_outlined,
      },
      'Achiever': {
        'theme': 'Consistency & Growth',
        'description': 'Persistence beats talent when talent stops showing up.',
        'color': const Color(0xFFFF9800),
        'icon': Icons.military_tech_outlined,
      },
      'Advanced': {
        'theme': 'Mastery & Leadership',
        'description': 'Knowledge grows when shared.',
        'color': const Color(0xFF673AB7),
        'icon': Icons.workspace_premium_outlined,
      },
      'Expert': {
        'theme': 'Dedication & Excellence',
        'description': 'The path of mastery begins when it stops being easy.',
        'color': const Color(0xFF2196F3),
        'icon': Icons.stars_outlined,
      },
      'Prestige': {
        'theme': 'Legacy & Mastery',
        'description': 'You are no longer chasing excellence. You define it.',
        'color': const Color(0xFFAB47BC),
        'icon': Icons.diamond_outlined,
      },
      'Supreme': {
        'theme': 'Enlightenment & Legacy',
        'description': 'Those who master themselves master the world.',
        'color': const Color(0xFFFFD700),
        'icon': Icons.auto_awesome,
      },
    };

    return tierData[tier] ?? {
      'theme': '',
      'description': '',
      'color': Colors.grey,
      'icon': Icons.emoji_events,
    };
  }

  void _showRankDetails(LeaderboardRank rank) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RankDetailsSheet(rank: rank),
    );
  }
}

class _RankDetailsSheet extends StatelessWidget {
  final LeaderboardRank rank;

  const _RankDetailsSheet({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Rank Badge
            Center(
              child: RankBadgeWidget(
                rank: rank,
                size: 100,
                showLabel: false,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Rank Name
            Center(
              child: Text(
                rank.name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: rank.color,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tier Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: rank.getTierColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rank.tier} Tier',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: rank.getTierColor(),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // XP Range
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'XP Range',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${LeaderboardRankService().formatXP(rank.minXP)} - ${LeaderboardRankService().formatXP(rank.maxXP)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rank.color,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description
            _buildSection('Description', rank.description),
            
            if (rank.achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection('Achievements', rank.achievements),
            ],
            
            if (rank.psychology.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection('Psychology', rank.psychology),
            ],
            
            if (rank.visualTheme.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSection('Visual Theme', rank.visualTheme),
            ],
            
            const SizedBox(height: 32),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rank.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
