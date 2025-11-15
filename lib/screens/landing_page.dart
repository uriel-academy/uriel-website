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
              showPricing: false,
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
                  fontSize: isDesktop ? 48 : 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A1E3F),
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              // Subheadline
              Text(
                'Study Smarter, Not Harder',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              // Simplified value proposition
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Your complete study companion with 10,000+ past questions, AI-powered tools, approved textbooks, interactive trivia, flashcards, and personalized study plans. Study smarter, achieve more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
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
                'Join 10,000+ students already using Uriel Academy',
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFF8F9FA),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForTitle(title),
              color: const Color(0xFFD62828),
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
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

  IconData _getIconForTitle(String title) {
    if (title.contains('Past Questions')) return Icons.quiz;
    if (title.contains('Study Toolkit')) return Icons.auto_stories;
    if (title.contains('AI-Powered')) return Icons.psychology;
    return Icons.school;
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
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFD62828),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: const Text(
                'Most Popular',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1E3F),
                      ),
                    ),
                    if (period.isNotEmpty)
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1E3F),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
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
                    school: 'Achimota School',
                    quote: 'Uriel Academy helped me improve my WASSCE grades by 2 points. The past questions are exactly what came in the real exams!',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildTestimonialCard(
                    name: 'Kwame Asante',
                    school: 'Presbyterian Boys\' Senior High',
                    quote: 'The AI study plans are incredible. I never knew I was weak in certain topics until Uriel showed me.',
                    width: isDesktop ? (constraints.maxWidth - 40) / 3 : constraints.maxWidth,
                  ),
                  _buildTestimonialCard(
                    name: 'Ama Osei',
                    school: 'Wesley Girls\' High School',
                    quote: 'Best educational app for Ghanaian students. The textbooks are exactly what we use in school.',
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
