import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/leaderboard_rank_service.dart';
import '../widgets/xp_earning_guide.dart';

/// Apple-inspired Ranks Page with cinematic scroll experience
class RedesignedAllRanksPage extends StatefulWidget {
  final int? userXP;

  const RedesignedAllRanksPage({super.key, this.userXP});

  @override
  State<RedesignedAllRanksPage> createState() => _RedesignedAllRanksPageState();
}

class _RedesignedAllRanksPageState extends State<RedesignedAllRanksPage> 
    with TickerProviderStateMixin {
  final LeaderboardRankService _rankService = LeaderboardRankService();
  final ScrollController _scrollController = ScrollController();
  
  List<LeaderboardRank> _allRanks = [];
  LeaderboardRank? _userCurrentRank;
  bool _isLoading = true;
  double _scrollProgress = 0.0;
  
  late AnimationController _heroAnimationController;
  late Animation<double> _heroFadeAnimation;
  late Animation<double> _heroScaleAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    _heroAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _heroFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _heroScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _loadRanks();
    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _heroAnimationController.dispose();
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
                'Loading your journey...',
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

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero Section
          SliverToBoxAdapter(child: _buildHeroSection()),
          
          // Philosophy Section
          SliverToBoxAdapter(child: _buildPhilosophySection()),
          
          // User's Current Progress (if logged in)
          if (_userCurrentRank != null)
            SliverToBoxAdapter(child: _buildUserProgressSection()),
          
          // Tier Sections
          ..._buildTierSections(),
          
          // Visual Tier Reference
          SliverToBoxAdapter(child: _buildTierColorReference()),
          
          // XP Earning Guide
          const SliverToBoxAdapter(child: XPEarningGuide()),
          
          // Final CTA
          SliverToBoxAdapter(child: _buildFinalCTA()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(_scrollProgress > 0.1 ? 0.95 : 0),
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

  Widget _buildHeroSection() {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            const Color(0xFFFAFAFA).withOpacity(0.5),
          ],
        ),
      ),
      child: FadeTransition(
        opacity: _heroFadeAnimation,
        child: ScaleTransition(
          scale: _heroScaleAnimation,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFloatingIcon('✨', delay: 0),
                      const SizedBox(width: 24),
                      _buildFloatingIcon('🏆', delay: 200, size: 64),
                      const SizedBox(width: 24),
                      _buildFloatingIcon('✨', delay: 400),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Hero Title
                  Text(
                    'The Journey of Mastery',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D1D1F),
                      height: 1.1,
                      letterSpacing: -1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tagline
                  Text(
                    '28 Ranks. One Path.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF6E6E73),
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'From Learner to Enlightened.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF86868B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Scroll Indicator
                  _buildScrollIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(String emoji, {int delay = 0, double size = 48}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Text(
            emoji,
            style: TextStyle(fontSize: size),
          ),
        );
      },
    );
  }

  Widget _buildScrollIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: value,
          duration: const Duration(milliseconds: 500),
          child: Column(
            children: [
              Text(
                'Scroll to explore',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF86868B),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _heroAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 8 * (1 - _heroAnimationController.value)),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF86868B),
                      size: 32,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhilosophySection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 48,
        vertical: isSmallScreen ? 80 : 120,
      ),
      color: Colors.white,
      child: Column(
        children: [
          // Quote
          Text(
            '"Ranks in Uriel aren\'t about competition - they\'re about growth."',
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonText(
              fontSize: isSmallScreen ? 32 : 48,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
              height: 1.3,
              fontStyle: FontStyle.italic,
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Every learner\'s path is unique,\nbut the journey is shared.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6E6E73),
              height: 1.5,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 64 : 96),
          
          // Principle Cards
          isSmallScreen 
              ? Column(
                  children: [
                    _buildPrincipleCard(
                      icon: Icons.trending_up_rounded,
                      title: 'Progress',
                      subtitle: 'Not Perfection',
                    ),
                    const SizedBox(height: 24),
                    _buildPrincipleCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Purpose',
                      subtitle: 'Not Points',
                    ),
                    const SizedBox(height: 24),
                    _buildPrincipleCard(
                      icon: Icons.people_rounded,
                      title: 'Community',
                      subtitle: 'Not Competition',
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildPrincipleCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Progress',
                        subtitle: 'Not Perfection',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildPrincipleCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Purpose',
                        subtitle: 'Not Points',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildPrincipleCard(
                        icon: Icons.people_rounded,
                        title: 'Community',
                        subtitle: 'Not Competition',
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildPrincipleCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD2D2D7), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 32,
                color: const Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6E6E73),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProgressSection() {
    if (_userCurrentRank == null) return const SizedBox.shrink();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final nextRank = _allRanks.firstWhere(
      (rank) => rank.rank == _userCurrentRank!.rank + 1,
      orElse: () => _userCurrentRank!,
    );
    final progressPercent = ((widget.userXP! - _userCurrentRank!.minXP) / 
        (_userCurrentRank!.maxXP - _userCurrentRank!.minXP) * 100).clamp(0, 100);
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 48,
        vertical: isSmallScreen ? 40 : 64,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 24 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _userCurrentRank!.getTierColor(),
            _userCurrentRank!.getTierColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _userCurrentRank!.getTierColor().withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User's current rank badge with local asset
              Container(
                width: isSmallScreen ? 60 : 80,
                height: isSmallScreen ? 60 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/leaderboards_rank/rank_${_userCurrentRank!.rank}.${_userCurrentRank!.rank == 19 ? "jpg" : "png"}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white,
                        child: Icon(
                          Icons.emoji_events,
                          size: isSmallScreen ? 30 : 40,
                          color: _userCurrentRank!.getTierColor(),
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
                      'Your Current Rank',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userCurrentRank!.name,
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 24 : 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_rankService.formatXP(widget.userXP!)} XP',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to ${nextRank.name}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${progressPercent.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_rankService.formatXP(nextRank.minXP - widget.userXP!)} XP to next rank',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTierSections() {
    final tiers = {
      'Beginner': {'color': const Color(0xFF4CAF50), 'icon': '🌱'},
      'Achiever': {'color': const Color(0xFFFF9800), 'icon': '⚔️'},
      'Advanced': {'color': const Color(0xFF673AB7), 'icon': '💎'},
      'Expert': {'color': const Color(0xFF2196F3), 'icon': '🌟'},
      'Prestige': {'color': const Color(0xFFAB47BC), 'icon': '👑'},
      'Supreme': {'color': const Color(0xFFFFD700), 'icon': '✨'},
    };

    List<Widget> sections = [];
    
    for (var entry in tiers.entries) {
      final tierName = entry.key;
      final tierData = entry.value;
      final tierRanks = _allRanks.where((r) => r.tier == tierName).toList();
      
      if (tierRanks.isEmpty) continue;
      
      // Tier Section
      sections.add(SliverToBoxAdapter(
        child: _buildTierHeader(
          tierName,
          tierData['color'] as Color,
          tierData['icon'] as String,
        ),
      ));
      
      // Rank Cards
      for (var rank in tierRanks) {
        sections.add(SliverToBoxAdapter(
          child: _buildRankCard(rank),
        ));
      }
      
      // Tier Transition (except for last tier)
      if (tierName != 'Supreme') {
        sections.add(SliverToBoxAdapter(
          child: _buildTierTransition(
            tierData['icon'] as String,
            tiers.entries.elementAt(tiers.keys.toList().indexOf(tierName) + 1).value['icon'] as String,
            tierName,
            tiers.keys.elementAt(tiers.keys.toList().indexOf(tierName) + 1),
          ),
        ));
      }
    }
    
    return sections;
  }

  Widget _buildTierHeader(String tierName, Color tierColor, String emoji) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      margin: EdgeInsets.only(
        left: isSmallScreen ? 24 : 48,
        right: isSmallScreen ? 24 : 48,
        top: isSmallScreen ? 64 : 96,
        bottom: isSmallScreen ? 32 : 48,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 32 : 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierColor,
            tierColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: isSmallScreen ? 48 : 64),
          ),
          const SizedBox(height: 16),
          Text(
            '$tierName Tier',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 36 : 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getTierTheme(tierName),
            style: GoogleFonts.crimsonText(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getTierDescription(tierName),
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 15 : 17,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(LeaderboardRank rank) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final isCurrentRank = _userCurrentRank?.rank == rank.rank;
    final isLocked = widget.userXP != null && widget.userXP! < rank.minXP;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 24 : 48,
          vertical: isSmallScreen ? 12 : 16,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showRankDetails(rank),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
              decoration: BoxDecoration(
                color: isCurrentRank 
                    ? rank.getTierColor().withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCurrentRank 
                      ? rank.getTierColor()
                      : const Color(0xFFD2D2D7),
                  width: isCurrentRank ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isSmallScreen
                  ? Column(
                      children: [
                        _buildRankIcon(rank, isLocked, isCurrentRank),
                        const SizedBox(height: 20),
                        _buildRankInfo(rank, isLocked, isCurrentRank, isSmallScreen),
                      ],
                    )
                  : Row(
                      children: [
                        _buildRankIcon(rank, isLocked, isCurrentRank),
                        const SizedBox(width: 32),
                        Expanded(
                          child: _buildRankInfo(rank, isLocked, isCurrentRank, isSmallScreen),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankIcon(LeaderboardRank rank, bool isLocked, bool isCurrentRank) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect for current rank
        if (isCurrentRank)
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: rank.getTierColor().withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        
        // Rank Badge - Using local asset images
        Opacity(
          opacity: isLocked ? 0.3 : 1.0,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: rank.getTierColor().withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                          fontSize: 24,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // Lock Icon
        if (isLocked)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        
        // Current Rank Indicator
        if (isCurrentRank)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: rank.getTierColor(),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRankInfo(LeaderboardRank rank, bool isLocked, bool isCurrentRank, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: isSmallScreen ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isSmallScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Text(
              '${rank.rank}. ',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.w700,
                color: isLocked 
                    ? const Color(0xFF86868B)
                    : rank.getTierColor(),
              ),
            ),
            Text(
              rank.name,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.w700,
                color: isLocked 
                    ? const Color(0xFF86868B)
                    : const Color(0xFF1D1D1F),
              ),
            ),
            if (isCurrentRank) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rank.getTierColor(),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'YOU',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 8),
        
        Text(
          '${_rankService.formatXP(rank.minXP)} – ${_rankService.formatXP(rank.maxXP)} XP',
          textAlign: isSmallScreen ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isLocked 
                ? const Color(0xFF86868B)
                : rank.getTierColor(),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          rank.description,
          textAlign: isSmallScreen ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF6E6E73),
            height: 1.5,
          ),
        ),
        
        if (rank.psychology.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: isSmallScreen ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: rank.getTierColor(),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    rank.psychology,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6E6E73),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTierTransition(String fromEmoji, String toEmoji, String fromTier, String toTier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      height: isSmallScreen ? 200 : 300,
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 40 : 64),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fromEmoji,
                  style: TextStyle(fontSize: isSmallScreen ? 40 : 56),
                ),
                const SizedBox(width: 24),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: isSmallScreen ? 32 : 48,
                  color: const Color(0xFF86868B),
                ),
                const SizedBox(width: 24),
                Text(
                  toEmoji,
                  style: TextStyle(fontSize: isSmallScreen ? 40 : 56),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$fromTier → $toTier',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6E6E73),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierColorReference() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    final tiers = [
      {'name': 'Beginner', 'color': const Color(0xFF4CAF50), 'emotion': 'Hope & Discovery'},
      {'name': 'Achiever', 'color': const Color(0xFFFF9800), 'emotion': 'Pride & Determination'},
      {'name': 'Advanced', 'color': const Color(0xFF673AB7), 'emotion': 'Growth & Ambition'},
      {'name': 'Expert', 'color': const Color(0xFF2196F3), 'emotion': 'Mastery & Wisdom'},
      {'name': 'Prestige', 'color': const Color(0xFFAB47BC), 'emotion': 'Rarity & Excellence'},
      {'name': 'Supreme', 'color': const Color(0xFFFFD700), 'emotion': 'Legacy & Enlightenment'},
    ];
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 24 : 48,
        vertical: isSmallScreen ? 64 : 96,
      ),
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          Text(
            'Understanding Tier Colors',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 32 : 42,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 48 : 64),
          
          isSmallScreen
              ? Column(
                  children: tiers.map((tier) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTierColorCard(
                      tier['name'] as String,
                      tier['color'] as Color,
                      tier['emotion'] as String,
                    ),
                  )).toList(),
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: tiers.map((tier) => SizedBox(
                    width: (screenWidth - 96 - 48) / 3, // 3 columns with spacing
                    child: _buildTierColorCard(
                      tier['name'] as String,
                      tier['color'] as Color,
                      tier['emotion'] as String,
                    ),
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildTierColorCard(String name, Color color, String emotion) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2D2D7), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            emotion,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF6E6E73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalCTA() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFAFAFA),
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Begin Your Journey',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 42 : 56,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F),
                height: 1.1,
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Start earning XP today.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 18 : 22,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6E6E73),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Every rank begins with a click.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 16 : 20,
                fontWeight: FontWeight.w300,
                color: const Color(0xFF86868B),
              ),
            ),
            
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Already climbing?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF86868B),
              ),
            ),
            
            const SizedBox(height: 8),
            
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Return to Dashboard',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF1D1D1F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRankDetails(LeaderboardRank rank) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RankDetailsSheet(rank: rank),
    );
  }

  String _getTierTheme(String tier) {
    const themes = {
      'Beginner': 'Discovery & Curiosity',
      'Achiever': 'Consistency & Growth',
      'Advanced': 'Mastery & Leadership',
      'Expert': 'Dedication & Excellence',
      'Prestige': 'Legacy & Mastery',
      'Supreme': 'Enlightenment & Legacy',
    };
    return themes[tier] ?? '';
  }

  String _getTierDescription(String tier) {
    const descriptions = {
      'Beginner': '"Every great learner starts with a single question."',
      'Achiever': '"Persistence beats talent when talent stops showing up."',
      'Advanced': '"Knowledge grows when shared."',
      'Expert': '"The path of mastery begins when it stops being easy."',
      'Prestige': '"You are no longer chasing excellence. You define it."',
      'Supreme': '"Those who master themselves master the world."',
    };
    return descriptions[tier] ?? '';
  }
}

// Details Sheet (same as before but with updated styling)
class _RankDetailsSheet extends StatelessWidget {
  final LeaderboardRank rank;

  const _RankDetailsSheet({required this.rank});

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
            
            // Rank image in details sheet
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: rank.getTierColor().withOpacity(0.4),
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
              rank.name,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: rank.getTierColor(),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: rank.getTierColor().withOpacity(0.1),
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
                    'XP Range',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF6E6E73),
                    ),
                  ),
                  Text(
                    '${LeaderboardRankService().formatXP(rank.minXP)} - ${LeaderboardRankService().formatXP(rank.maxXP)}',
                    style: GoogleFonts.firaCode(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: rank.getTierColor(),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildSection('Description', rank.description),
            
            if (rank.achievements.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection('Achievements', rank.achievements),
            ],
            
            if (rank.psychology.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSection('Psychology', rank.psychology),
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

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6E6E73),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF1D1D1F),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
