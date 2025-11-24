import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import '../widgets/common_footer.dart';
import '../utils/navigation_helper.dart';
import 'sign_up.dart';
import 'sign_in.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _scrollController = ScrollController();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Header/Navigation
            _buildHeader(context, isSmallScreen),
            
            // Hero Section
            _buildHeroSection(isSmallScreen),
            
            // Mission & Vision
            _buildMissionSection(isSmallScreen),
            
            // What We Offer
            _buildOfferingsSection(isSmallScreen),
            
            // Why We Exist
            _buildWhyWeExistSection(isSmallScreen),
            
            // What Makes Us Different
            _buildDifferentiatorSection(isSmallScreen),
            
            // Future Vision
            _buildFutureSection(isSmallScreen),
            
            // CTA Section
            _buildCTASection(isSmallScreen),
            
            // Footer
            CommonFooter(
              isSmallScreen: isSmallScreen,
              showLinks: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: 16,
      ),
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
      child: Row(
        children: [
          // Logo
          GestureDetector(
            onTap: () async {
              final homeRoute = await NavigationHelper.getUserHomeRoute();
              Navigator.pushReplacementNamed(context, homeRoute);
            },
            child: Text(
              'Uriel Academy',
              style: AppStyles.brandNameLight(fontSize: isSmallScreen ? 18 : 22),
            ),
          ),
          
          const Spacer(),
          
          // Navigation (Desktop) - removed for cleaner look
          if (!isSmallScreen) ...[
            const SizedBox(width: 32),
          ],
          
          // Get Started Button
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignUpPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 32,
                vertical: isSmallScreen ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 4,
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 60 : 80,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 800),
              child: Column(
                children: [
                  Text(
                    'About Us',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isSmallScreen ? 32 : 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      'Learn. Practice. Succeed.',
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD62828),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  Text(
                    'That\'s not just our tagline—it\'s our promise.',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 16 : 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 20 : 24),
                  
                  Text(
                    'Uriel Academy was created with one simple goal: to make learning easier, smarter, and more fun for every Ghanaian student preparing for BECE and WASSCE.',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 1200),
        child: Column(
          children: [
            Text(
              'Our Mission & Vision',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 48),
            
            if (isSmallScreen) ...[
              _buildMissionCard('Our Vision', 'To be the most trusted digital learning partner in Ghana and across Africa, helping students not only pass exams, but truly understand, grow, and succeed.', true),
              const SizedBox(height: 24),
              _buildMissionCard('Our Mission', 'Accessibility – Affordable, mobile-first learning for every student.\nExcellence – High-quality, exam-ready content tailored for Ghanaian curricula.\nInnovation – AI-powered tools, gamification, and personalized learning journeys.\nCommunity – Students, parents, and schools working together for better results.', true),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildMissionCard('Our Vision', 'To be the most trusted digital learning partner in Ghana and across Africa, helping students not only pass exams, but truly understand, grow, and succeed.', false),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _buildMissionCard('Our Mission', 'Accessibility – Affordable, mobile-first learning for every student.\nExcellence – High-quality, exam-ready content tailored for Ghanaian curricula.\nInnovation – AI-powered tools, gamification, and personalized learning journeys.\nCommunity – Students, parents, and schools working together for better results.', false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(String title, String content, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingsSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 1200),
        child: Column(
          children: [
            Text(
              'What We Offer',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 48),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isSmallScreen ? 1 : 2,
              childAspectRatio: isSmallScreen ? 2.2 : 2.0,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              children: [
                _buildOfferingCard(
                  '10,000+ Past Questions',
                  'Carefully organized BECE and WASSCE past questions, with instant solutions, mock exams, and practice quizzes.',
                  isSmallScreen,
                ),
                _buildOfferingCard(
                  'NACCA-Approved Textbooks',
                  'Your entire bookshelf, online. Study any subject anytime, anywhere—without carrying a heavy bag.',
                  isSmallScreen,
                ),
                _buildOfferingCard(
                  'AI Learning Tools',
                  'Our friendly AI assistant helps you solve problems, summarize textbooks, create revision plans, and even chat with you in Twi, Ga, Ewe, or Hausa.',
                  isSmallScreen,
                ),
                _buildOfferingCard(
                  'Parent & School Insights',
                  'Students focus on learning, while parents get progress updates straight to email or WhatsApp. Schools can track class performance with just a click.',
                  isSmallScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferingCard(String title, String description, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            description,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyWeExistSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      color: Colors.grey[50],
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 800),
        child: Column(
          children: [
            Text(
              'Why We Exist',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            Text(
              'Education is changing, but too many students are still left behind because:',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 16 : 18,
                color: Colors.grey[700],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            Column(
              children: [
                _buildProblemItem('Textbooks are expensive.', isSmallScreen),
                _buildProblemItem('Past papers aren\'t always easy to find.', isSmallScreen),
                _buildProblemItem('Schools lack digital learning support.', isSmallScreen),
                _buildProblemItem('Parents struggle to track progress.', isSmallScreen),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 40),
            
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Uriel Academy bridges that gap.',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD62828),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'With affordable pricing (as little as GHS 2.99 a week), we\'re proving that quality education doesn\'t have to be a luxury—it should be for everyone.',
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProblemItem(String text, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFD62828),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifferentiatorSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 1000),
        child: Column(
          children: [
            Text(
              'What Makes Us Different',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 48),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isSmallScreen ? 1 : 2,
              childAspectRatio: isSmallScreen ? 2.5 : 2.2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              children: [
                _buildDifferentiatorCard('Student-First', 'Built for mobile, designed for speed.', Icons.phone_android, const Color(0xFF4CAF50), isSmallScreen),
                _buildDifferentiatorCard('Fun Learning', 'Study streaks, badges, contests, and Uri cheering you on.', Icons.emoji_events, const Color(0xFFFF9800), isSmallScreen),
                _buildDifferentiatorCard('Practical Tools', 'Weekly revision plans, offline packs, and exam-mode practice.', Icons.build, const Color(0xFF2196F3), isSmallScreen),
                _buildDifferentiatorCard('Caring Support', 'Wellness tips, calm learning mode, and motivation that puts your well-being first.', Icons.favorite, const Color(0xFFE91E63), isSmallScreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifferentiatorCard(String title, String description, IconData icon, Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureSection(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD62828).withValues(alpha: 0.1),
            const Color(0xFF1A1E3F).withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 800),
        child: Column(
          children: [
            Text(
              'The Future',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 24 : 32),
            
            Text(
              'Today, we\'re helping JHS and SHS students. Tomorrow, we\'ll grow with you.',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            Text(
              'From Uriel Kids for early learners to advanced tools for universities, we\'re building a learning ecosystem that never stops evolving.',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[700],
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 20 : 24),
            
            Text(
              'Because at Uriel, we believe every child deserves the tools to succeed—no matter where they start.',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFD62828),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCTASection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1E3F), Color(0xFF2D3561)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Uriel Academy',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          Text(
            'For the students who dream bigger, the parents who care deeply, and the schools shaping tomorrow\'s leaders.',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 16 : 18,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 32 : 40),
          
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 32 : 48,
                    vertical: isSmallScreen ? 16 : 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                ),
                child: Text(
                  'Join Uriel Academy',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 16 : 24),
              
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 32 : 48,
                    vertical: isSmallScreen ? 16 : 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
