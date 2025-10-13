import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Comprehensive XP Earning Guide Widget
class XPEarningGuide extends StatelessWidget {
  const XPEarningGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 48),
      color: const Color(0xFFFAFAFA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'How to Earn XP',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 32 : 42,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Master the learning platform and climb the ranks faster!',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 16 : 18,
              color: const Color(0xFF6E6E73),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 32 : 48),
          
          // XP Categories
          if (isSmallScreen)
            Column(
              children: [
                _buildXPCategory(
                  icon: Icons.quiz_outlined,
                  title: 'Quiz Mastery',
                  color: const Color(0xFF4CAF50),
                  items: _getQuizItems(),
                ),
                const SizedBox(height: 24),
                _buildXPCategory(
                  icon: Icons.auto_awesome,
                  title: 'Achievements',
                  color: const Color(0xFFFF9800),
                  items: _getAchievementItems(),
                ),
                const SizedBox(height: 24),
                _buildXPCategory(
                  icon: Icons.menu_book,
                  title: 'Reading & Study',
                  color: const Color(0xFF673AB7),
                  items: _getReadingItems(),
                ),
                const SizedBox(height: 24),
                _buildXPCategory(
                  icon: Icons.calendar_today,
                  title: 'Consistency',
                  color: const Color(0xFF2196F3),
                  items: _getConsistencyItems(),
                ),
              ],
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: (screenWidth - 96 - 24) / 2,
                  child: _buildXPCategory(
                    icon: Icons.quiz_outlined,
                    title: 'Quiz Mastery',
                    color: const Color(0xFF4CAF50),
                    items: _getQuizItems(),
                  ),
                ),
                SizedBox(
                  width: (screenWidth - 96 - 24) / 2,
                  child: _buildXPCategory(
                    icon: Icons.auto_awesome,
                    title: 'Achievements',
                    color: const Color(0xFFFF9800),
                    items: _getAchievementItems(),
                  ),
                ),
                SizedBox(
                  width: (screenWidth - 96 - 24) / 2,
                  child: _buildXPCategory(
                    icon: Icons.menu_book,
                    title: 'Reading & Study',
                    color: const Color(0xFF673AB7),
                    items: _getReadingItems(),
                  ),
                ),
                SizedBox(
                  width: (screenWidth - 96 - 24) / 2,
                  child: _buildXPCategory(
                    icon: Icons.calendar_today,
                    title: 'Consistency',
                    color: const Color(0xFF2196F3),
                    items: _getConsistencyItems(),
                  ),
                ),
              ],
            ),
          
          SizedBox(height: isSmallScreen ? 48 : 64),
          
          // XP Strategy Section
          _buildStrategySection(isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 48 : 64),
          
          // Progression Calculator
          _buildProgressionCalculator(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildXPCategory({
    required IconData icon,
    required String title,
    required Color color,
    required List<XPItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2D2D7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // XP Items
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildXPItem(item, color),
          )),
        ],
      ),
    );
  }

  Widget _buildXPItem(XPItem item, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.action,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF1D1D1F),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${item.xp} XP',
                  style: GoogleFonts.firaCode(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategySection(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Text(
                'Smart XP Strategies',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildStrategyTip(
            '🎯 Aim for Perfect Scores',
            'Getting 100% on quizzes earns you bonus XP. Review topics before attempting!',
          ),
          
          const SizedBox(height: 16),
          
          _buildStrategyTip(
            '🔥 Build Daily Streaks',
            'Login every day and maintain 7-day streaks for massive bonus XP.',
          ),
          
          const SizedBox(height: 16),
          
          _buildStrategyTip(
            '🗺️ Explore All Categories',
            'First-time completion in each category gives 50 XP bonus. Try everything!',
          ),
          
          const SizedBox(height: 16),
          
          _buildStrategyTip(
            '👑 Chase Master Explorer',
            'Complete all 12 trivia categories for 100 XP bonus badge.',
          ),
          
          const SizedBox(height: 16),
          
          _buildStrategyTip(
            '📚 Read Regularly',
            'Reading sessions and book completions stack up. Study daily!',
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyTip(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressionCalculator(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progression Examples',
          style: GoogleFonts.inter(
            fontSize: isSmallScreen ? 28 : 36,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        
        const SizedBox(height: 24),
        
        Text(
          'See how different learning styles progress through the ranks:',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF6E6E73),
          ),
        ),
        
        const SizedBox(height: 32),
        
        if (isSmallScreen)
          Column(
            children: [
              _buildProgressionCard(
                title: 'Casual Learner',
                subtitle: '1 quiz per day',
                color: const Color(0xFF4CAF50),
                stats: const ProgressionStats(
                  dailyXP: 100,
                  weeklyXP: 700,
                  monthlyXP: 3000,
                  timeToScholar: '2 weeks',
                  timeToMaster: '3 months',
                ),
              ),
              const SizedBox(height: 16),
              _buildProgressionCard(
                title: 'Active Student',
                subtitle: '2-3 quizzes + daily login',
                color: const Color(0xFFFF9800),
                stats: const ProgressionStats(
                  dailyXP: 260,
                  weeklyXP: 1820,
                  monthlyXP: 7800,
                  timeToScholar: '1 week',
                  timeToMaster: '6 weeks',
                ),
              ),
              const SizedBox(height: 16),
              _buildProgressionCard(
                title: 'Dedicated Grinder',
                subtitle: '5+ quizzes + reading + streaks',
                color: const Color(0xFF673AB7),
                stats: const ProgressionStats(
                  dailyXP: 550,
                  weeklyXP: 3850,
                  monthlyXP: 16500,
                  timeToScholar: '3 days',
                  timeToMaster: '3 weeks',
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProgressionCard(
                  title: 'Casual Learner',
                  subtitle: '1 quiz per day',
                  color: const Color(0xFF4CAF50),
                  stats: const ProgressionStats(
                    dailyXP: 100,
                    weeklyXP: 700,
                    monthlyXP: 3000,
                    timeToScholar: '2 weeks',
                    timeToMaster: '3 months',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressionCard(
                  title: 'Active Student',
                  subtitle: '2-3 quizzes + daily login',
                  color: const Color(0xFFFF9800),
                  stats: const ProgressionStats(
                    dailyXP: 260,
                    weeklyXP: 1820,
                    monthlyXP: 7800,
                    timeToScholar: '1 week',
                    timeToMaster: '6 weeks',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressionCard(
                  title: 'Dedicated Grinder',
                  subtitle: '5+ quizzes + reading + streaks',
                  color: const Color(0xFF673AB7),
                  stats: const ProgressionStats(
                    dailyXP: 550,
                    weeklyXP: 3850,
                    monthlyXP: 16500,
                    timeToScholar: '3 days',
                    timeToMaster: '3 weeks',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildProgressionCard({
    required String title,
    required String subtitle,
    required Color color,
    required ProgressionStats stats,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6E6E73),
            ),
          ),
          
          const SizedBox(height: 20),
          
          _buildStatRow('Daily', '${stats.dailyXP} XP'),
          const SizedBox(height: 8),
          _buildStatRow('Weekly', '${stats.weeklyXP} XP'),
          const SizedBox(height: 8),
          _buildStatRow('Monthly', '${stats.monthlyXP} XP'),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildTimeRow('To Scholar (10K)', stats.timeToScholar),
                const SizedBox(height: 8),
                _buildTimeRow('To Master (50K)', stats.timeToMaster),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF6E6E73),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D1D1F),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(String milestone, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          milestone,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6E6E73),
          ),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  List<XPItem> _getQuizItems() {
    return const [
      XPItem(action: 'Answer correctly', xp: 5),
      XPItem(action: 'Perfect score (100%)', xp: 20),
      XPItem(action: 'First time in category', xp: 50),
      XPItem(action: 'Complete 40-question quiz', xp: 200),
    ];
  }

  List<XPItem> _getAchievementItems() {
    return const [
      XPItem(action: 'Master Explorer badge', xp: 100),
      XPItem(action: '7-day streak bonus', xp: 300),
      XPItem(action: 'Monthly contest winner', xp: 5000),
      XPItem(action: 'Subject module completion', xp: 1500),
    ];
  }

  List<XPItem> _getReadingItems() {
    return const [
      XPItem(action: 'Reading session', xp: 15),
      XPItem(action: 'Complete a book', xp: 50),
      XPItem(action: 'Textbook chapter', xp: 10),
      XPItem(action: 'AI revision plan', xp: 500),
    ];
  }

  List<XPItem> _getConsistencyItems() {
    return const [
      XPItem(action: 'Daily login', xp: 10),
      XPItem(action: '7-day streak', xp: 300),
      XPItem(action: '30-day streak', xp: 1500),
      XPItem(action: 'Perfect attendance (month)', xp: 2000),
    ];
  }
}

class XPItem {
  final String action;
  final int xp;

  const XPItem({required this.action, required this.xp});
}

class ProgressionStats {
  final int dailyXP;
  final int weeklyXP;
  final int monthlyXP;
  final String timeToScholar;
  final String timeToMaster;

  const ProgressionStats({
    required this.dailyXP,
    required this.weeklyXP,
    required this.monthlyXP,
    required this.timeToScholar,
    required this.timeToMaster,
  });
}
