import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/leaderboard_rank_service.dart';

/// Widget to display user's rank badge
class RankBadgeWidget extends StatelessWidget {
  final LeaderboardRank rank;
  final double size;
  final bool showLabel;
  final bool showGlow;

  const RankBadgeWidget({
    super.key,
    required this.rank,
    this.size = 64,
    this.showLabel = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rank Badge Image with Glow
        Container(
          width: size,
          height: size,
          decoration: showGlow
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: rank.color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                )
              : null,
          child: CachedNetworkImage(
            imageUrl: rank.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => CircleAvatar(
              radius: size / 2,
              backgroundColor: rank.color.withOpacity(0.2),
              child: Icon(
                rank.getTierIcon(),
                color: rank.color,
                size: size * 0.5,
              ),
            ),
            errorWidget: (context, url, error) => CircleAvatar(
              radius: size / 2,
              backgroundColor: rank.color,
              child: Text(
                rank.rank.toString(),
                style: GoogleFonts.montserrat(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // Rank Label
        if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            rank.name,
            style: GoogleFonts.playfairDisplay(
              fontSize: size * 0.2,
              fontWeight: FontWeight.bold,
              color: rank.color,
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget to display rank progress card
class RankProgressCard extends StatelessWidget {
  final LeaderboardRank currentRank;
  final LeaderboardRank? nextRank;
  final int userXP;
  final VoidCallback? onViewAllRanks;

  const RankProgressCard({
    super.key,
    required this.currentRank,
    this.nextRank,
    required this.userXP,
    this.onViewAllRanks,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentRank.getProgressInRank(userXP);
    final xpToNext = nextRank != null 
        ? (nextRank!.minXP - userXP) 
        : 0;
    final rankService = LeaderboardRankService();

    // Soft navy color palette
    const cardColor = Color(0xFF4A5568); // Soft slate gray/navy
    const accentColor = Color(0xFF2D3748); // Darker navy
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            accentColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                currentRank.getTierIcon(),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Rank',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currentRank.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Rank Badge as CircleAvatar with border
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: currentRank.imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(currentRank.imageUrl)
                      : null,
                  child: currentRank.imageUrl.isEmpty
                      ? Icon(
                          Icons.emoji_events,
                          color: currentRank.getTierColor(),
                          size: 30,
                        )
                      : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Current XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${rankService.formatXP(userXP)} XP',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${currentRank.tier} Tier',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          if (nextRank != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${rankService.formatXP(xpToNext)} XP to ${nextRank!.name}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ] else ...[
            // Max Rank Achieved
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Maximum Rank Achieved! 🎉',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Description
          Text(
            currentRank.description,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),

          // View All Ranks Button
          if (onViewAllRanks != null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: onViewAllRanks,
                icon: const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                label: Text(
                  'View All Ranks',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget to display rank in a list
class RankListTile extends StatelessWidget {
  final LeaderboardRank rank;
  final bool isCurrentRank;
  final bool isLocked;
  final VoidCallback? onTap;

  const RankListTile({
    super.key,
    required this.rank,
    this.isCurrentRank = false,
    this.isLocked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentRank 
            ? rank.color.withOpacity(0.1) 
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentRank
            ? Border.all(color: rank.color, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            RankBadgeWidget(
              rank: rank,
              size: 50,
              showLabel: false,
              showGlow: isCurrentRank,
            ),
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            if (isCurrentRank)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD62828),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Text(
              rank.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.grey : const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(width: 8),
            if (rank.isUltimate)
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rank.getTierColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rank.tier,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: rank.getTierColor(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${LeaderboardRankService().formatXP(rank.minXP)} - ${LeaderboardRankService().formatXP(rank.maxXP)} XP',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            if (!isLocked) ...[
              const SizedBox(height: 8),
              Text(
                rank.description,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: isLocked
            ? null
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: rank.color,
              ),
        onTap: isLocked ? null : onTap,
      ),
    );
  }
}

/// Rank Up Animation Dialog
class RankUpDialog extends StatelessWidget {
  final LeaderboardRank newRank;
  final int earnedXP;

  const RankUpDialog({
    super.key,
    required this.newRank,
    required this.earnedXP,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              newRank.getTierColor(),
              newRank.getTierColor().withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: newRank.color.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Icon
            const Icon(
              Icons.celebration,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Rank Up!',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              LeaderboardRankService().getRankUpMessage(newRank),
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Rank Badge
            RankBadgeWidget(
              rank: newRank,
              size: 100,
              showLabel: false,
            ),
            
            const SizedBox(height: 16),
            
            // New Rank Name
            Text(
              newRank.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // XP Earned
            Text(
              '+${LeaderboardRankService().formatXP(earnedXP)} XP',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: newRank.color,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context, LeaderboardRank newRank, int earnedXP) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RankUpDialog(
        newRank: newRank,
        earnedXP: earnedXP,
      ),
    );
  }
}
