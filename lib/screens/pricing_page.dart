import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/common_footer.dart';
import '../constants/app_styles.dart';
import '../models/subscription_plan_selection.dart';
import '../utils/navigation_helper.dart';

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
            onTap: () async {
              final homeRoute = await NavigationHelper.getUserHomeRoute();
              Navigator.pushReplacementNamed(context, homeRoute);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Uriel',
                  style: AppStyles.brandNameLight(fontSize: isMobile ? 18 : 22),
                ),
                Text(
                  'Academy',
                  style: AppStyles.brandNameLight(fontSize: isMobile ? 18 : 22),
                ),
              ],
            ),
          ),
          if (!isMobile)
            TextButton(
              onPressed: () async {
                final homeRoute = await NavigationHelper.getUserHomeRoute();
                Navigator.pushReplacementNamed(context, homeRoute);
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
              color: urielNavy.withValues(alpha: 0.7),
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
              border: Border.all(color: urielNavy.withValues(alpha: 0.2)),
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? urielNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            color: isSelected ? Colors.white : urielNavy,
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 13 : 14,
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
      child: Column(
        children: [
          // All 4 cards in one row for desktop
          isMobile
              ? Column(
                  children: [
                    _buildPricingCard('Free', 'Get Started', 0, 0, _freeFeatures(), false, false, isMobile),
                    const SizedBox(height: 20),
                    _buildPricingCard('Standard', 'Everything You Need to Pass BECE', 9.99, 99.99, _standardFeatures(), false, true, isMobile),
                    const SizedBox(height: 20),
                    _buildPricingCard('Premium', 'Learn 2x Faster with AI', 14.99, 149.99, _premiumFeatures(), true, false, isMobile),
                    const SizedBox(height: 20),
                    _buildSchoolCard(isMobile),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildPricingCard('Free', 'Get Started', 0, 0, _freeFeatures(), false, false, isMobile),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPricingCard('Standard', 'Everything You Need to Pass BECE', 9.99, 99.99, _standardFeatures(), false, true, isMobile),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPricingCard('Premium', 'Learn 2x Faster with AI', 14.99, 149.99, _premiumFeatures(), true, false, isMobile),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildSchoolCard(isMobile),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  List<String> _freeFeatures() {
    return [
      'Trivia & gamification - Fun learning challenges',
      'Classic literature - Access to reading materials',
      '5 past questions per subject per month',
      '1 textbook chapter per subject',
      'Notes Tab - View only access',
      'Community support',
    ];
  }

  List<String> _standardFeatures() {
    return [
      'All textbooks - Every subject, JHS 1-3, NACCA-aligned',
      'All past questions - 1990-2024, every BECE subject',
      'Student dashboard - Track your progress in real-time',
      'Weekly parent reports - Automated SMS/WhatsApp updates',
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
    ];
  }

  List<String> _schoolFeatures() {
    return [
      'Teacher dashboard - Track every student',
      'Class analytics - Identify weak topics',
      'Content upload - Share notes directly',
      'School-wide analytics & reporting',
      'Custom branding options',
      'Dedicated account manager',
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
          color: isPremium ? urielRed : Colors.grey.withValues(alpha: 0.3),
          width: isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urielRed,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier,
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? urielRed : urielNavy,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 13 : 14,
                    color: isPremium ? Colors.black : urielNavy.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GHS',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: urielNavy,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayPrice == 0 ? '0' : displayPrice.toStringAsFixed(2),
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 40 : 48,
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
                      color: urielNavy.withValues(alpha: 0.6),
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
                    onPressed: () {
                      final selectedFeatures = tier == 'Free' ? _freeFeatures() : features;
                      final planSelection = SubscriptionPlanSelection(
                        id: tier.toLowerCase().replaceAll(' ', '-'),
                        name: tier,
                        subtitle: subtitle,
                        monthlyPrice: monthlyPrice,
                        annualPrice: annualPrice,
                        isAnnual: isAnnual,
                        features: selectedFeatures,
                      );
                      Navigator.pushNamed(
                        context,
                        '/payment',
                        arguments: planSelection,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPremium ? urielRed : urielNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Continue to payment',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
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
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'School Plan',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.bold,
                    color: urielNavy,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  'For Schools & Educational Institutions',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 14 : 18,
                    color: urielNavy.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 32),
                Text(
                  'Custom Pricing',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: urielNavy,
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 32),
                ..._schoolFeatures().map((feature) => _buildSchoolFeatureItem(feature, isMobile)).toList(),
                SizedBox(height: isMobile ? 20 : 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/contact');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: urielNavy,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Request School Demo',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 16 : 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolFeatureItem(String text, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getFeatureIcon(text),
            size: isMobile ? 20 : 28,
            color: Colors.black,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 13 : 16,
                color: urielNavy.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFeatureIcon(String text) {
    // Special case for "Everything in" text
    if (text.contains('Everything in')) return Icons.stars;
    
    // Feature-specific icons
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
    if (text.contains('gamification') || text.contains('achievement') || text.contains('Advanced gamification')) return Icons.emoji_events;
    if (text.contains('Ad-free') || text.contains('distraction')) return Icons.block;
    if (text.contains('WhatsApp') || text.contains('chat')) return Icons.chat;
    if (text.contains('teacher') || text.contains('Teacher')) return Icons.school;
    if (text.contains('analytics') || text.contains('Analytics')) return Icons.analytics;
    if (text.contains('content') || text.contains('Content')) return Icons.cloud_upload;
    if (text.contains('branding') || text.contains('logo') || text.contains('Custom branding')) return Icons.branding_watermark;
    if (text.contains('training') || text.contains('onboarding')) return Icons.cast_for_education;
    if (text.contains('trivia') || text.contains('Trivia')) return Icons.extension;
    if (text.contains('literature') || text.contains('reading') || text.contains('Classic literature')) return Icons.auto_stories;
    if (text.contains('tracking') || text.contains('Track')) return Icons.track_changes;
    if (text.contains('Community') || text.contains('school rankings')) return Icons.people;
    if (text.contains('leaderboard')) return Icons.emoji_events;
    if (text.contains('chapter') || text.contains('sample')) return Icons.description;
    if (text.contains('classic')) return Icons.auto_stories;
    if (text.contains('per month') || text.contains('per subject')) return Icons.calendar_month;
    if (text.contains('View only')) return Icons.visibility;
    if (text.contains('account manager') || text.contains('Dedicated')) return Icons.person_pin;
    if (text.contains('School-wide') || text.contains('reporting')) return Icons.summarize;
    
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
            color: Colors.black,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: urielNavy.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(bool isMobile) {
    return Center(
      child: Container(
        width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.75,
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 60,
          vertical: 40,
        ),
        child: Column(
          children: [
            // Section Header
            Text(
              'Compare Plans',
              style: GoogleFonts.playfairDisplay(
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.bold,
                color: urielNavy,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose the perfect plan for your learning journey',
              style: GoogleFonts.montserrat(
                fontSize: isMobile ? 14 : 16,
                color: urielNavy.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Comparison Grid
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: urielNavy.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: urielNavy.withValues(alpha: 0.04),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: isMobile
                  ? _buildMobileComparison()
                  : _buildDesktopComparison(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopComparison() {
    final features = [
      {'name': 'Pricing', 'free': 'GHS 0', 'standard': 'GHS 9.99/mo', 'premium': 'GHS 14.99/mo', 'school': 'Custom'},
      {'name': 'Trivia Challenges', 'free': true, 'standard': true, 'premium': true, 'school': true},
      {'name': 'Classic Literature', 'free': true, 'standard': true, 'premium': true, 'school': true},
      {'name': 'Past Questions', 'free': '5/month', 'standard': 'Unlimited', 'premium': 'Unlimited', 'school': 'Unlimited'},
      {'name': 'Textbooks Access', 'free': '1 chapter', 'standard': 'Full access', 'premium': 'Full access', 'school': 'Full access'},
      {'name': 'Uri AI Tutor', 'free': false, 'standard': false, 'premium': true, 'school': true},
      {'name': 'Notes Tab', 'free': 'View only', 'standard': 'View only', 'premium': 'Upload & Share', 'school': 'Upload & Share'},
      {'name': 'Mock Exams', 'free': false, 'standard': '1/subject', 'premium': 'Unlimited', 'school': 'Unlimited'},
      {'name': 'Progress Dashboard', 'free': 'Basic', 'standard': 'Advanced', 'premium': 'Premium', 'school': 'School-wide'},
      {'name': 'Teacher Dashboard', 'free': false, 'standard': false, 'premium': false, 'school': true},
      {'name': 'Parent Reports', 'free': false, 'standard': 'Weekly SMS', 'premium': 'Weekly SMS', 'school': 'Custom'},
      {'name': 'Support', 'free': 'Community', 'standard': 'Email 48hr', 'premium': 'Priority', 'school': 'Dedicated'},
    ];

    return Column(
      children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: urielNavy.withValues(alpha: 0.02),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Features',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: urielNavy.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: _buildPlanHeader('Free', null),
              ),
              Expanded(
                child: _buildPlanHeader('Standard', urielGreen),
              ),
              Expanded(
                child: _buildPlanHeader('Premium', urielRed),
              ),
              Expanded(
                child: _buildPlanHeader('School', urielNavy),
              ),
            ],
          ),
        ),
        
        // Feature Rows
        ...features.asMap().entries.map((entry) {
          final index = entry.key;
          final feature = entry.value;
          final isLast = index == features.length - 1;
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Colors.white : urielNavy.withValues(alpha: 0.01),
              borderRadius: isLast ? const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ) : null,
              border: Border(
                bottom: isLast ? BorderSide.none : BorderSide(
                  color: urielNavy.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    feature['name'] as String,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: urielNavy,
                    ),
                  ),
                ),
                Expanded(child: _buildFeatureValue(feature['free'])),
                Expanded(child: _buildFeatureValue(feature['standard'])),
                Expanded(child: _buildFeatureValue(feature['premium'])),
                Expanded(child: _buildFeatureValue(feature['school'])),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMobileComparison() {
    final features = [
      {'name': 'Pricing', 'free': 'GHS 0', 'standard': 'GHS 9.99/mo', 'premium': 'GHS 14.99/mo', 'school': 'Custom'},
      {'name': 'Trivia Challenges', 'free': true, 'standard': true, 'premium': true, 'school': true},
      {'name': 'Classic Literature', 'free': true, 'standard': true, 'premium': true, 'school': true},
      {'name': 'Past Questions', 'free': '5/month', 'standard': 'Unlimited', 'premium': 'Unlimited', 'school': 'Unlimited'},
      {'name': 'Textbooks Access', 'free': '1 chapter', 'standard': 'Full access', 'premium': 'Full access', 'school': 'Full access'},
      {'name': 'Uri AI Tutor', 'free': false, 'standard': false, 'premium': true, 'school': true},
      {'name': 'Notes Tab', 'free': 'View only', 'standard': 'View only', 'premium': 'Upload', 'school': 'Upload'},
      {'name': 'Mock Exams', 'free': false, 'standard': '1/subject', 'premium': 'Unlimited', 'school': 'Unlimited'},
      {'name': 'Progress Dashboard', 'free': 'Basic', 'standard': 'Advanced', 'premium': 'Premium', 'school': 'School-wide'},
      {'name': 'Teacher Dashboard', 'free': false, 'standard': false, 'premium': false, 'school': true},
      {'name': 'Parent Reports', 'free': false, 'standard': 'Weekly', 'premium': 'Weekly', 'school': 'Custom'},
      {'name': 'Support', 'free': 'Community', 'standard': 'Email 48h', 'premium': 'Priority', 'school': 'Dedicated'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Plan selector tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: urielNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildPlanTab('Free', 0),
                _buildPlanTab('Standard', 1),
                _buildPlanTab('Premium', 2),
                _buildPlanTab('School', 3),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Selected plan details
          _buildMobilePlanComparison(features),
        ],
      ),
    );
  }

  int _selectedMobilePlan = 2; // Default to Premium
  
  Widget _buildPlanTab(String name, int index) {
    final isSelected = _selectedMobilePlan == index;
    Color planColor = urielNavy;
    if (name == 'Standard') planColor = urielGreen;
    if (name == 'Premium') planColor = urielRed;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMobilePlan = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [
              BoxShadow(
                color: planColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Text(
                name,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? planColor : urielNavy.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: planColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePlanComparison(List<Map<String, dynamic>> features) {
    final plans = ['free', 'standard', 'premium', 'school'];
    final selectedPlan = plans[_selectedMobilePlan];
    
    return Column(
      children: features.map((feature) {
        final value = feature[selectedPlan];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: urielNavy.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: urielNavy.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  feature['name'] as String,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: urielNavy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildMobileFeatureValue(value),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileFeatureValue(dynamic value) {
    if (value is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value 
              ? urielGreen.withValues(alpha: 0.1) 
              : urielNavy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: value ? urielGreen : urielNavy.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),
            Text(
              value ? 'Yes' : 'No',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? urielGreen : urielNavy.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: urielNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.toString(),
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: urielNavy.withValues(alpha: 0.8),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPlanHeader(String name, Color? accentColor) {
    return Column(
      children: [
        Text(
          name,
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor ?? urielNavy,
          ),
          textAlign: TextAlign.center,
        ),
        if (accentColor != null) ...[
          const SizedBox(height: 6),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureValue(dynamic value) {
    if (value is bool) {
      return Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: value 
                ? urielGreen.withValues(alpha: 0.1) 
                : urielNavy.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            value ? Icons.check : Icons.close,
            size: 16,
            color: value ? urielGreen : urielNavy.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    
    return Text(
      value.toString(),
      style: GoogleFonts.montserrat(
        fontSize: 14,
        color: urielNavy.withValues(alpha: 0.8),
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTestimonials(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 60,
        vertical: 40,
      ),
      color: urielNavy.withValues(alpha: 0.05),
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
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: urielNavy.withValues(alpha: 0.1),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: isMobile ? 16 : 20)),
          SizedBox(height: isMobile ? 10 : 12),
          Text(
            quote,
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 13 : 14,
              color: urielNavy,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            name,
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: urielNavy,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 11 : 12,
              color: urielNavy.withValues(alpha: 0.6),
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
                  color: urielNavy.withValues(alpha: 0.1),
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
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: GoogleFonts.montserrat(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                color: urielNavy,
                              ),
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.remove : Icons.add,
                            color: urielNavy,
                            size: isMobile ? 20 : 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: EdgeInsets.only(
                        left: isMobile ? 16 : 20,
                        right: isMobile ? 16 : 20,
                        bottom: isMobile ? 16 : 20,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq['answer']!,
                          style: GoogleFonts.montserrat(
                            fontSize: isMobile ? 13 : 14,
                            color: urielNavy.withValues(alpha: 0.7),
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
