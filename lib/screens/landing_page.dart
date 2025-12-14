import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import '../widgets/common_footer.dart';
import 'sign_up.dart';
import 'sign_in.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildHeroSection(context),
            _buildValueProposition(context),
            _buildPricingSection(context),
            _buildTestimonialsSection(context),
                        // Footer
            CommonFooter(
              isSmallScreen: screenWidth < 768,
              showLinks: true,
              showPricing: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Text(
              'Uriel Academy',
              style: AppStyles.brandNameLight(fontSize: 22),
            ),
            
            const Spacer(),
            
            // Auth Buttons
            Row(
              children: [
                TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1E3F),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD62828),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 768;
          
          return Column(
            children: [
              const SizedBox(height: 60),
              // Main Headline
              Text(
                    'LEARN. PRACTICE. SUCCEED.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: isDesktop ? 50.5 : 32,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1A1E3F),
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
              const SizedBox(height: 16),
              // Subheadline
              Text(
                'Turn screen time into exam wins.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lobsterTwo(
                  fontSize: isDesktop ? 26.5 : 20,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFD62828),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              // Simplified value proposition
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Your all-in-one BECE study companion with 12,000+ past questions (and growing), curriculum-aligned textbooks, revision plans, grade predictions, AI tools, and peer-shared notes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 20.5 : 18,
                    color: Colors.grey[700],
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // CTA Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start preparing today!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Fast, mobile-first, and exam-focused.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
            ],
          );
        },
      ),
    );
  }

  Widget _buildValueProposition(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Everything you need to excel',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 768;
              
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildFeatureCard(
                    title: '10,000+ Past Questions',
                    description: 'Access BECE, WASSCE, and NOVDEC past questions with comprehensive answers and explanations',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildFeatureCard(
                    title: 'Complete Study Toolkit',
                    description: 'Approved textbooks, interactive flashcards, educational trivia, and smart revision notes',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildFeatureCard(
                    title: 'AI-Powered Learning',
                    description: 'Personalized study plans, intelligent progress tracking, and adaptive quiz generation',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String description,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF8F9FA),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD62828).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62828).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            'Choose your plan',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Affordable pricing designed for Ghanaian students',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 768;
              
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildPricingCard(
                    context: context,
                    title: 'Free',
                    subtitle: 'Get Started',
                    price: 'GHS 0',
                    period: '/month',
                    features: [
                      'Trivia & gamification',
                      'Classic literature',
                      '5 past questions/subject/month',
                      '1 textbook chapter/subject',
                      'Notes Tab - View only',
                      'Community support',
                    ],
                    isPopular: false,
                    width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                  ),
                  _buildPricingCard(
                    context: context,
                    title: 'Standard',
                    subtitle: 'Everything You Need',
                    price: 'GHS 9.99',
                    period: '/month',
                    features: [
                      'All textbooks - JHS 1-3',
                      'All past questions - 1990-2024',
                      'Student dashboard',
                      'Weekly parent reports',
                      'Priority support - Email 48hr',
                    ],
                    isPopular: false,
                    width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                  ),
                  _buildPricingCard(
                    context: context,
                    title: 'Premium',
                    subtitle: 'Learn 2x Faster with AI',
                    price: 'GHS 14.99',
                    period: '/month',
                    features: [
                      'Everything in Standard, plus:',
                      'Uri AI Tutor - Unlimited',
                      'Notes Tab - Upload your own',
                      'Unlimited mock exams',
                      'Personalized study plans',
                      'Calm Learning Mode',
                      'Advanced gamification',
                    ],
                    isPopular: true,
                    width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                  ),
                  _buildPricingCard(
                    context: context,
                    title: 'School Plan',
                    subtitle: 'For Institutions',
                    price: 'Custom',
                    period: '',
                    features: [
                      'Teacher dashboard',
                      'Class analytics',
                      'Content upload',
                      'School-wide analytics',
                      'Custom branding',
                      'Dedicated account manager',
                    ],
                    isPopular: false,
                    width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
    required double width,
  }) {
    // Mobile-responsive font sizes
    final isMobile = width < 200;
    final titleSize = isMobile ? 16.0 : 18.0;
    final subtitleSize = isMobile ? 11.0 : 13.0;
    final priceSize = isMobile ? 20.0 : 24.0;
    final periodSize = isMobile ? 12.0 : 14.0;
    final featureSize = isMobile ? 12.0 : 14.0;
    final cardPadding = isMobile ? 12.0 : 20.0;
    
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? const Color(0xFFD62828) : Colors.grey.shade200,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: const BoxDecoration(
                color: Color(0xFFD62828),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 10 : 12,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1E3F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        price,
                        style: TextStyle(
                          fontSize: priceSize,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1E3F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (period.isNotEmpty)
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: periodSize,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 20),
                ...features.map((feature) => Padding(
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFF4CAF50),
                        size: isMobile ? 14 : 16,
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            fontSize: featureSize,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                SizedBox(height: isMobile ? 12 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular ? const Color(0xFFD62828) : const Color(0xFF1A1E3F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 14,
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

  Widget _buildTestimonialsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            'Trusted by students across Ghana',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 768;
              
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildTestimonialCard(
                    name: 'Akosua Mensah',
                    school: 'Ave Maria School',
                    quote: 'Uriel Academy helped me prepare for my BECE exams. The past questions and practice tests really boosted my confidence!',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildTestimonialCard(
                    name: 'Kwame Asante',
                    school: 'Morning Star International School',
                    quote: 'The AI study plans are incredible. I never knew I was weak in certain topics until Uriel showed me where to improve.',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildTestimonialCard(
                    name: 'Ama Osei',
                    school: 'SAPS School',
                    quote: 'Best app for JHS students! The textbooks and notes are exactly what we need for BECE preparation.',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard({
    required String name,
    required String school,
    required String quote,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (index) => const Icon(
              Icons.star,
              color: Color(0xFFFFC107),
              size: 16,
            )),
          ),
          const SizedBox(height: 16),
          Text(
            '"$quote"',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1E3F),
            ),
          ),
          Text(
            school,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
