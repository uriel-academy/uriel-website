import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/leaderboard_rank_service.dart';

/// Minimal Apple-inspired Ranks Page with Trailhead-style grid layout
class RedesignedAllRanksPage extends StatefulWidget {
  final int? userXP;

  const RedesignedAllRanksPage({super.key, this.userXP});

  @override
  State<RedesignedAllRanksPage> createState() => _RedesignedAllRanksPageState();
}

class _RedesignedAllRanksPageState extends State<RedesignedAllRanksPage> {
  final LeaderboardRankService _rankService = LeaderboardRankService();
  final ScrollController _scrollController = ScrollController();
  
  List<LeaderboardRank> _allRanks = [];
  LeaderboardRank? _userCurrentRank;
  bool _isLoading = true;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRanks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    setState(() {
      _scrollProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    });
  }

  Future<void> _loadRanks() async {
    setState(() => _isLoading = true);
    
    try {
      final ranks = await _rankService.getAllRanks();
      // Filter: Only show ranks 1-28
      final filteredRanks = ranks.where((r) => r.rank >= 1 && r.rank <= 28).toList();
      
      LeaderboardRank? currentRank;
      if (widget.userXP != null) {
        currentRank = await _rankService.getUserRank(widget.userXP!);
      }
      
      setState(() {
        _allRanks = filteredRanks;
        _userCurrentRank = currentRank;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading ranks: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF1D1D1F),
                strokeWidth: 2,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Ranks...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF6E6E73),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final isMediumScreen = screenWidth >= 768 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Hero Header
            _buildHeroHeader(isSmallScreen),
            
            // User's Current Rank (if logged in)
            if (_userCurrentRank != null) ...[
              _buildUserCurrentRank(isSmallScreen),
            ],

            // Ranks Grid
            _buildRanksGrid(isSmallScreen, isMediumScreen),
            
            // XP Economy table placed before the footer
            _buildXPEconomySection(isSmallScreen),
            
            // Footer CTA
            _buildFooter(isSmallScreen),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: _scrollProgress > 0.1 ? 0.95 : 0),
      elevation: _scrollProgress > 0.1 ? 1 : 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        color: const Color(0xFF1D1D1F),
        onPressed: () => Navigator.pop(context),
      ),
      title: AnimatedOpacity(
        opacity: _scrollProgress > 0.3 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Text(
          'Ranks',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D1D1F),
          ),
        ),
      ),
      centerTitle: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 64,
        vertical: isSmallScreen ? 60 : 100,
      ),
      child: Column(
        children: [
          // Inspirational quote
          Text(
            '"Ranks in Uriel aren\'t about competition. They\'re about growth. Every learner\'s path is unique, but the journey is shared."',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6E6E73),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Text(
            'Climb the Ranks',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 40 : 56,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '28 Ranks. Endless possibilities.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 18 : 24,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6E6E73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCurrentRank(bool isSmallScreen) {
    final nextRank = _allRanks.firstWhere(
      (rank) => rank.rank == _userCurrentRank!.rank + 1,
      orElse: () => _userCurrentRank!,
    );
    final xpNeeded = nextRank.minXP - widget.userXP!;
    final progressPercent = _userCurrentRank!.rank == nextRank.rank 
        ? 100.0 
        : ((widget.userXP! - _userCurrentRank!.minXP) / (nextRank.minXP - _userCurrentRank!.minXP) * 100).clamp(0.0, 100.0);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 64,
        vertical: 32,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
      decoration: BoxDecoration(
        color: _userCurrentRank!.getTierColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _userCurrentRank!.getTierColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Badge
              Container(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 60 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _userCurrentRank!.getTierColor().withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/leaderboards_rank/rank_${_userCurrentRank!.rank}.${_userCurrentRank!.rank == 19 ? "jpg" : "png"}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: _userCurrentRank!.getTierColor(),
                        child: Center(
                          child: Text(
                            '${_userCurrentRank!.rank}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR RANK',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _userCurrentRank!.getTierColor(),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userCurrentRank!.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 20 : 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_rankService.formatXP(widget.userXP!)} XP',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6E6E73),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Progress Bar (synced with leaderboard)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to ${nextRank.name.toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6E6E73),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${progressPercent.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _userCurrentRank!.getTierColor(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: const Color(0xFFE5E5EA),
                  valueColor: AlwaysStoppedAnimation<Color>(_userCurrentRank!.getTierColor()),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                xpNeeded > 0 ? "${_rankService.formatXP(xpNeeded)} XP to next rank" : "Max rank achieved!",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF86868B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRanksGrid(bool isSmallScreen, bool isMediumScreen) {
    int crossAxisCount;
    if (isSmallScreen) {
      crossAxisCount = 2;
    } else if (isMediumScreen) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 64,
        vertical: 32,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: isSmallScreen ? 0.85 : 0.75,
          crossAxisSpacing: isSmallScreen ? 12 : 24,
          mainAxisSpacing: isSmallScreen ? 12 : 24,
        ),
        itemCount: _allRanks.length,
        itemBuilder: (context, index) {
          return _buildRankGridCard(_allRanks[index], isSmallScreen);
        },
      ),
    );
  }

  Widget _buildRankGridCard(LeaderboardRank rank, bool isSmallScreen) {
    final isCurrentRank = _userCurrentRank?.rank == rank.rank;
    final isLocked = widget.userXP != null && widget.userXP! < rank.minXP;
    
    return GestureDetector(
      onTap: () => _showRankDetails(rank),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentRank 
              ? rank.getTierColor().withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentRank 
                ? rank.getTierColor()
                : const Color(0xFFE5E5EA),
            width: isCurrentRank ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge
            Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSmallScreen ? 80 : 100,
                    height: isSmallScreen ? 80 : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isCurrentRank ? [
                        BoxShadow(
                          color: rank.getTierColor().withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ] : [],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/leaderboards_rank/rank_${rank.rank}.${rank.rank == 19 ? "jpg" : "png"}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: rank.getTierColor(),
                            child: Center(
                              child: Text(
                                '${rank.rank}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (isCurrentRank)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: rank.getTierColor(),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Rank Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                rank.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 13 : 15,
                  fontWeight: FontWeight.w700,
                  color: isLocked 
                      ? const Color(0xFF86868B)
                      : const Color(0xFF1D1D1F),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // XP Range
            Text(
              '${_rankService.formatXP(rank.minXP)}–${_rankService.formatXP(rank.maxXP)}',
              style: GoogleFonts.firaCode(
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: isLocked 
                    ? const Color(0xFF86868B)
                    : rank.getTierColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 64,
        vertical: isSmallScreen ? 60 : 100,
      ),
      child: Column(
        children: [
          Text(
            'Start Your Journey',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 32 : 48,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete lessons, earn XP, and climb the ranks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 16 : 20,
              color: const Color(0xFF6E6E73),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D1D1F),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 32 : 48,
                vertical: isSmallScreen ? 16 : 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// XP Economy section — shows XP sources and rewards in a compact table
  Widget _buildXPEconomySection(bool isSmallScreen) {
    final headerStyle = GoogleFonts.inter(
      fontSize: isSmallScreen ? 16 : 18,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1D1D1F),
    );

    final cellStyle = GoogleFonts.inter(
      fontSize: isSmallScreen ? 13 : 14,
      color: const Color(0xFF1D1D1F),
    );

    final noteStyle = GoogleFonts.inter(
      fontSize: isSmallScreen ? 12 : 13,
      color: const Color(0xFF6E6E73),
    );

    Widget row(String action, String reward, String notes) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(action, style: cellStyle),
              ),
              Expanded(
                flex: 2,
                child: Text(reward, style: cellStyle),
              ),
              Expanded(
                flex: 4,
                child: Text(notes, style: noteStyle),
              ),
            ],
          ),
        );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 64, vertical: 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('📈  XP Economy', style: headerStyle),
            ],
          ),
          const SizedBox(height: 12),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 4, child: Text('Action', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('XP Reward', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700))),
                    Expanded(flex: 4, child: Text('Notes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700))),
                  ],
                ),
                const Divider(height: 18),
                // Rows
                row('Daily login', '50 XP', ''),
                row('Completing a quiz (40 questions)', '200 XP', '5 XP per question + completion bonus'),
                row('Perfect quiz score (≥90%)', '+100 XP bonus', ''),
                row('Uploading notes', '150 XP', ''),
                row('Receiving upvotes/downloads on notes', '+10 XP per upvote', ''),
                row('Completing AI Revision Plan', '500 XP', ''),
                row('Maintaining 7-day streak', '+300 XP bonus', ''),
                row('Achieving new badge', '250–500 XP', ''),
                row('Finishing a full subject module', '1000–2000 XP', ''),
                row('Monthly contest (winner)', '5000 XP', ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRankDetails(LeaderboardRank rank) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RankDetailsSheet(rank: rank, rankService: _rankService),
    );
  }
}

// Rank Details Modal
class _RankDetailsSheet extends StatelessWidget {
  final LeaderboardRank rank;
  final LeaderboardRankService rankService;

  const _RankDetailsSheet({
    required this.rank,
    required this.rankService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
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
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD2D2D7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            // Badge
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: rank.getTierColor().withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/leaderboards_rank/rank_${rank.rank}.${rank.rank == 19 ? "jpg" : "png"}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: rank.getTierColor(),
                      child: Center(
                        child: Text(
                          '${rank.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              rank.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: rank.getTierColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${rank.tier} Tier',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: rank.getTierColor(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'XP RANGE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6E6E73),
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${rankService.formatXP(rank.minXP)} – ${rankService.formatXP(rank.maxXP)}',
                    style: GoogleFonts.firaCode(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: rank.getTierColor(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DESCRIPTION',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6E6E73),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rank.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF1D1D1F),
                height: 1.6,
              ),
            ),
            if (rank.achievements.isNotEmpty) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ACHIEVEMENTS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6E6E73),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rank.achievements,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF1D1D1F),
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rank.getTierColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
