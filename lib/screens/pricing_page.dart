import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/common_footer.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({Key? key}) : super(key: key);

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool isAnnual = false;
  bool showComparison = false;
  int selectedFAQ = -1;

  final urielNavy = const Color(0xFF1A1E3F);
  final urielRed = const Color(0xFFD62828);
  final urielGreen = const Color(0xFF2ECC71);
  final urielWarmWhite = const Color(0xFFF8FAFE);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: urielWarmWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, isMobile),
            _buildHeroSection(isMobile),
            _buildPricingCards(isMobile),
            _buildComparisonTable(isMobile),
            _buildTestimonials(isMobile),
            _buildFAQ(isMobile),
            _buildFooter(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              final isLoggedIn = FirebaseAuth.instance.currentUser != null;
              Navigator.pushReplacementNamed(
                context,
                isLoggedIn ? '/home' : '/landing',
              );
            },
            child: Image.asset(
              'assets/uriel_logo.png',
              height: isMobile ? 32 : 40,
            ),
          ),
          if (!isMobile)
            TextButton(
              onPressed: () {
                final isLoggedIn = FirebaseAuth.instance.currentUser != null;
                Navigator.pushReplacementNamed(
                  context,
                  isLoggedIn ? '/home' : '/landing',
                );
              },
              child: Text(
                'Back to Home',
                style: GoogleFonts.montserrat(color: urielNavy),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: isMobile ? 40 : 60,
      ),
      child: Column(
        children: [
          Text(
            'Choose Your Plan',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'All plans include access to trivia challenges and curated classic literature',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 14 : 18,
              color: urielNavy.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Annual/Monthly Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: urielNavy.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton('Monthly', !isAnnual, () {
                  setState(() => isAnnual = false);
                }),
                _buildToggleButton('Annual (Save 17%)', isAnnual, () {
                  setState(() => isAnnual = true);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? urielNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            color: isSelected ? Colors.white : urielNavy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCards(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 40,
      ),
      child: isMobile
          ? Column(
              children: [
                _buildPricingCard('Free', 'Get Started', 0, 0, [], false, false, isMobile),
                const SizedBox(height: 20),
                _buildPricingCard('Standard', 'Everything You Need to Pass BECE', 9.99, 99, _standardFeatures(), false, true, isMobile),
                const SizedBox(height: 20),
                _buildPricingCard('Premium', 'Learn 2x Faster with AI', 14.99, 149, _premiumFeatures(), true, false, isMobile),
                const SizedBox(height: 20),
                _buildSchoolCard(isMobile),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPricingCard('Free', 'Get Started', 0, 0, [], false, false, isMobile),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildPricingCard('Standard', 'Everything You Need to Pass BECE', 9.99, 99, _standardFeatures(), false, true, isMobile),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildPricingCard('Premium', 'Learn 2x Faster with AI', 14.99, 149, _premiumFeatures(), true, false, isMobile),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSchoolCard(isMobile),
                ),
              ],
            ),
    );
  }

  List<String> _standardFeatures() {
    return [
      'All textbooks - Every subject, JHS 1-3, NACCA-aligned',
      'All past questions - 1990-2024, every BECE subject',
      'Student dashboard - Track your progress in real-time',
      'Weekly parent reports - Automated SMS/WhatsApp updates',
      'Offline downloads - Study without data (5 chapters)',
      'Priority support - Email response within 48 hours',
    ];
  }

  List<String> _premiumFeatures() {
    return [
      'Everything in Standard, plus:',
      'Uri AI Tutor - Ask unlimited questions, get instant explanations',
      'Notes Tab - Access peer & teacher notes, upload your own',
      'Unlimited mock exams - AI-generated practice tests',
      'Personalized study plans - AI analyzes weak areas',
      'Calm Learning Mode - Focus timer, progress badges',
      'Advanced gamification - Achievements, streaks, competitions',
      'Unlimited offline downloads - Study anytime, anywhere',
      'Ad-free experience - Zero distractions',
      'WhatsApp support - Get help within 4 hours',
    ];
  }

  Widget _buildPricingCard(
    String tier,
    String subtitle,
    double monthlyPrice,
    double annualPrice,
    List<String> features,
    bool isPremium,
    bool isBestValue,
    bool isMobile,
  ) {
    final displayPrice = isAnnual ? annualPrice : monthlyPrice;
    final period = isAnnual ? 'year' : 'month';
    final savings = isAnnual && monthlyPrice > 0 ? (monthlyPrice * 12) - annualPrice : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFFFD700)
              : isBestValue
                  ? urielNavy
                  : urielNavy.withOpacity(0.2),
          width: isPremium || isBestValue ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: urielNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      transform: isPremium ? Matrix4.translationValues(0, -10, 0) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium || isBestValue)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isPremium ? const Color(0xFFFFD700) : urielNavy,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isPremium) const Text('⭐', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    isPremium ? 'Most Popular' : 'Best Value',
                    style: GoogleFonts.montserrat(
                      color: isPremium ? urielNavy : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier,
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: urielNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: urielNavy.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GHS',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: urielNavy,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayPrice == 0 ? '0' : displayPrice.toStringAsFixed(2),
                      style: GoogleFonts.montserrat(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: urielNavy,
                      ),
                    ),
                  ],
                ),
                if (monthlyPrice > 0) ...[
                  Text(
                    displayPrice == 0 ? 'Forever free' : '/$period',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: urielNavy.withOpacity(0.6),
                    ),
                  ),
                  if (savings > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Save GHS ${savings.toStringAsFixed(0)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: urielGreen,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                if (tier == 'Free') ...[
                  _buildFeatureItem('Unlimited trivia challenges with leaderboards'),
                  _buildFeatureItem('Access to classic literature library'),
                  _buildFeatureItem('5 past questions per subject per month'),
                  _buildFeatureItem('1 sample chapter from each textbook'),
                  _buildFeatureItem('Basic progress tracking'),
                  _buildFeatureItem('Community features & school rankings'),
                ] else
                  ...features.map((f) => _buildFeatureItem(f)).toList(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tier == 'Free'
                          ? Colors.transparent
                          : isPremium
                              ? const Color(0xFFFFD700)
                              : urielNavy,
                      foregroundColor: tier == 'Free'
                          ? urielNavy
                          : isPremium
                              ? urielNavy
                              : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: tier == 'Free'
                            ? BorderSide(color: urielNavy)
                            : BorderSide.none,
                      ),
                      elevation: tier == 'Free' ? 0 : 2,
                    ),
                    child: Text(
                      tier == 'Free'
                          ? 'Start Free'
                          : tier == 'Standard'
                              ? 'Start Standard'
                              : 'Upgrade to Premium',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (tier == 'Standard') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: urielGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Replaces GHS 1,600 in textbooks',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: urielGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (tier == 'Premium') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Learn 2x faster with AI-powered revision',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB8860B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9B59B6),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: urielNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF9B59B6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              'For Institutions',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'School Plan',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: urielNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'For Schools & Educational Institutions',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: urielNavy.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Custom Pricing',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: urielNavy,
                  ),
                ),
                Text(
                  'From GHS 75/student/year',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: urielNavy.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                _buildFeatureItem('Teacher dashboard - Track every student'),
                _buildFeatureItem('Class analytics - Identify weak topics'),
                _buildFeatureItem('Content upload - Share notes directly'),
                _buildFeatureItem('School-wide analytics & reporting'),
                _buildFeatureItem('Custom branding options'),
                _buildFeatureItem('Dedicated account manager'),
                _buildFeatureItem('Teacher training & support'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Request School Demo',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'See how we help 50+ schools improve BECE scores',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: urielNavy.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon(String text) {
    if (text.contains('textbook') || text.contains('Books')) return Icons.menu_book;
    if (text.contains('question') || text.contains('quiz')) return Icons.quiz;
    if (text.contains('dashboard') || text.contains('progress')) return Icons.dashboard;
    if (text.contains('report') || text.contains('parent')) return Icons.assessment;
    if (text.contains('download') || text.contains('offline')) return Icons.download;
    if (text.contains('support') || text.contains('help')) return Icons.support_agent;
    if (text.contains('AI') || text.contains('Uri')) return Icons.psychology;
    if (text.contains('Notes') || text.contains('upload')) return Icons.note_add;
    if (text.contains('exam') || text.contains('test')) return Icons.assignment;
    if (text.contains('study plan') || text.contains('personalized')) return Icons.calendar_today;
    if (text.contains('Calm') || text.contains('focus')) return Icons.self_improvement;
    if (text.contains('gamification') || text.contains('achievement')) return Icons.emoji_events;
    if (text.contains('Ad-free') || text.contains('distraction')) return Icons.block;
    if (text.contains('WhatsApp') || text.contains('chat')) return Icons.chat;
    if (text.contains('teacher') || text.contains('Teacher')) return Icons.school;
    if (text.contains('analytics') || text.contains('Analytics')) return Icons.analytics;
    if (text.contains('content') || text.contains('Content')) return Icons.cloud_upload;
    if (text.contains('branding') || text.contains('logo')) return Icons.branding_watermark;
    if (text.contains('training') || text.contains('onboarding')) return Icons.cast_for_education;
    if (text.contains('trivia') || text.contains('Trivia')) return Icons.extension;
    if (text.contains('literature') || text.contains('reading')) return Icons.auto_stories;
    if (text.contains('tracking') || text.contains('Track')) return Icons.track_changes;
    if (text.contains('Community') || text.contains('school rankings')) return Icons.people;
    return Icons.check_circle;
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getFeatureIcon(text),
            size: 20,
            color: urielGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: urielNavy.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 40,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: urielNavy.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Compare Plans',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
          ),
          const SizedBox(height: 24),
          if (isMobile)
            Text(
              'Tap to expand table',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: urielNavy.withOpacity(0.6),
              ),
            ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(urielNavy.withOpacity(0.1)),
              columns: [
                DataColumn(
                  label: Text(
                    'Feature',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Free',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Standard',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Premium',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'School',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: [
                _buildComparisonRow('Price', 'GHS 0', 'GHS 9.99/mo', 'GHS 14.99/mo', 'From GHS 75/yr'),
                _buildComparisonRow('Trivia & gamification', '✅', '✅', '✅', '✅'),
                _buildComparisonRow('Classic literature', '✅', '✅', '✅', '✅'),
                _buildComparisonRow('Past questions', '5/subject/month', 'Unlimited', 'Unlimited', 'Unlimited'),
                _buildComparisonRow('Textbooks', '1 chapter', 'All chapters', 'All chapters', 'All chapters'),
                _buildComparisonRow('Uri AI Tutor', '❌', '❌', '✅', '✅'),
                _buildComparisonRow('Notes Tab', 'View only', 'View only', '✅ Upload', '✅ Upload'),
                _buildComparisonRow('Mock exams', '❌', '1/subject', 'Unlimited', 'Unlimited'),
                _buildComparisonRow('Teacher dashboard', '❌', '❌', '❌', '✅'),
                _buildComparisonRow('Support', 'Community', 'Email (48hr)', 'WhatsApp (4hr)', 'Dedicated'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildComparisonRow(String feature, String free, String standard, String premium, String school) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            feature,
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Text(free, style: GoogleFonts.montserrat(fontSize: 12))),
        DataCell(Text(standard, style: GoogleFonts.montserrat(fontSize: 12))),
        DataCell(Text(premium, style: GoogleFonts.montserrat(fontSize: 12))),
        DataCell(Text(school, style: GoogleFonts.montserrat(fontSize: 12))),
      ],
    );
  }

  Widget _buildTestimonials(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 40,
      ),
      color: urielNavy.withOpacity(0.05),
      child: Column(
        children: [
          Text(
            'Trusted by 10,000+ Students & 50+ Schools',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          isMobile
              ? Column(
                  children: [
                    _buildTestimonialCard(
                      '"Uri helped me understand Math concepts I\'d struggled with for months. I went from failing to scoring 80%!"',
                      'Kwame A.',
                      'JHS 3 student, Accra',
                      isMobile,
                    ),
                    const SizedBox(height: 20),
                    _buildTestimonialCard(
                      '"We\'ve seen a 25% improvement in average BECE scores since implementing Uriel Academy. The teacher dashboards are invaluable."',
                      'Mrs. Mensah',
                      'Headmistress, Royal Academy JHS',
                      isMobile,
                    ),
                    const SizedBox(height: 20),
                    _buildTestimonialCard(
                      '"My daughter actually looks forward to studying now. The gamification and Uri make learning fun!"',
                      'Mr. Boateng',
                      'Parent, Kumasi',
                      isMobile,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildTestimonialCard(
                        '"Uri helped me understand Math concepts I\'d struggled with for months. I went from failing to scoring 80%!"',
                        'Kwame A.',
                        'JHS 3 student, Accra',
                        isMobile,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTestimonialCard(
                        '"We\'ve seen a 25% improvement in average BECE scores since implementing Uriel Academy. The teacher dashboards are invaluable."',
                        'Mrs. Mensah',
                        'Headmistress, Royal Academy JHS',
                        isMobile,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildTestimonialCard(
                        '"My daughter actually looks forward to studying now. The gamification and Uri make learning fun!"',
                        'Mr. Boateng',
                        'Parent, Kumasi',
                        isMobile,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(String quote, String name, String title, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: urielNavy.withOpacity(0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          Text(
            quote,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: urielNavy,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: urielNavy.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ(bool isMobile) {
    final faqs = [
      {
        'question': 'Can I upgrade or downgrade anytime?',
        'answer': 'Yes! Upgrade instantly to access premium features. Downgrade at end of your billing cycle. No penalties.',
      },
      {
        'question': 'What payment methods do you accept?',
        'answer': 'MTN Mobile Money, Vodafone Cash, AirtelTigo Money, and card payments via Paystack.',
      },
      {
        'question': 'Do you offer refunds?',
        'answer': 'Yes. If you\'re not satisfied within 7 days, we\'ll refund you—no questions asked.',
      },
      {
        'question': 'Can schools try before buying?',
        'answer': 'Absolutely! We offer FREE 6-month pilot programs for schools. Contact us at schools@urielacademy.com',
      },
      {
        'question': 'Is my data safe?',
        'answer': 'Yes. All data is encrypted and stored securely. We never sell student information.',
      },
      {
        'question': 'What happens to my progress if I downgrade?',
        'answer': 'Your progress is saved forever. If you downgrade, you keep all your history—you just lose access to premium features.',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 40,
      ),
      child: Column(
        children: [
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            final isExpanded = selectedFAQ == index;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: urielNavy.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        selectedFAQ = isExpanded ? -1 : index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: urielNavy,
                              ),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.remove : Icons.add,
                            color: urielNavy,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq['answer']!,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: urielNavy.withOpacity(0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return CommonFooter(
      isSmallScreen: isMobile,
    );
  }
}
