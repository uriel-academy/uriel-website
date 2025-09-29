import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import 'sign_up.dart';
import 'sign_in.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> with TickerProviderStateMixin {
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
            
            // Terms Content
            _buildTermsContent(isSmallScreen),
            
            // Contact Section
            _buildContactSection(isSmallScreen),
            
            // Footer
            _buildFooter(isSmallScreen),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/landing'),
            child: Text(
              'Uriel Academy',
              style: AppStyles.brandNameLight(fontSize: isSmallScreen ? 18 : 22),
            ),
          ),
          
          const Spacer(),
          
          // Navigation - removed for cleaner look
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
        vertical: isSmallScreen ? 40 : 60,
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
                    'Terms of Service',
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Effective Date: 01-10-25',
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD62828),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  Text(
                    'Welcome to Uriel Academy. These Terms of Service govern your access to and use of the Uriel Academy website, mobile application, and related services.',
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

  Widget _buildTermsContent(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 20 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _buildTermsCard(
              '',
              'By using Uriel Academy, you agree to these Terms. If you do not agree, please do not use our Services.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 1: Who We Are
            _buildTermsCard(
              '1. Who We Are',
              'Uriel Academy is an EdTech platform designed for Ghanaian students preparing for BECE and WASSCE. We provide past questions, NACCA-approved textbooks, AI-powered study tools, progress tracking, and parent/school reporting.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 2: Eligibility
            _buildTermsCard(
              '2. Eligibility',
              '• Students under 18 must provide a parent/guardian email or WhatsApp number during registration\n• Schools and school admins must be authorized representatives of their institutions\n• By using our Services, you confirm that the information you provide is accurate',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 3: Accounts & Access
            _buildTermsCard(
              '3. Accounts & Access',
              '• Students create personal accounts using email, phone number, or Google sign-in\n• Parents/Guardians receive reports via email/WhatsApp and do not need separate logins\n• School Admins may manage multiple students, subject data, and performance analytics\n• You are responsible for keeping your login credentials secure',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 4: Subscription & Payments
            _buildTermsCard(
              '4. Subscription & Payments',
              '• Access to premium features (past questions, textbooks, AI tools) requires an active subscription\n• Pricing options include weekly, bi-weekly, monthly, and yearly plans\n• Payments are processed securely through trusted third-party providers (e.g., Paystack)\n• Subscriptions are non-transferable and non-refundable, except as required by law',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 5: Use of Services
            _buildTermsCard(
              '5. Use of Services',
              'You agree to:\n\n• Use the Services for personal, educational, and non-commercial purposes\n• Respect intellectual property rights of textbooks, past papers, and platform content\n• Avoid cheating, plagiarism, or misuse of AI features during studies or exams\n• Not attempt to hack, reverse-engineer, or disrupt platform functionality',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 6: Parent & School Reporting
            _buildTermsCard(
              '6. Parent & School Reporting',
              '• Students\' performance data may be shared with linked parents/guardians and schools\n• Reports are for guidance and progress tracking, not a substitute for teacher assessments',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 7: Content & Intellectual Property
            _buildTermsCard(
              '7. Content & Intellectual Property',
              '• All content (questions, textbooks, AI outputs, videos, and app design) belongs to Uriel Academy or our content partners\n• You may not copy, redistribute, or sell our materials without permission',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 8: Data Privacy
            _buildTermsCard(
              '8. Data Privacy',
              'Your privacy is important to us. Please read our Privacy Policy to understand how we collect, use, and protect your data.',
              isSmallScreen,
              hasPrivacyLink: true,
            ),
            
            const SizedBox(height: 24),
            
            // Section 9: Safety & Well-Being
            _buildTermsCard(
              '9. Safety & Well-Being',
              'Uriel Academy includes features like Calm Learning Mode, motivational messages, and break reminders. These are designed to support balanced study habits. They are not medical or mental health advice.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 10: Service Availability
            _buildTermsCard(
              '10. Service Availability',
              '• We strive to keep Uriel Academy online 24/7, but we do not guarantee uninterrupted access\n• We may suspend Services for maintenance, updates, or emergencies',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 11: Termination
            _buildTermsCard(
              '11. Termination',
              'We may suspend or terminate your account if you:\n\n• Violate these Terms\n• Engage in fraud, abuse, or academic dishonesty\n• Misuse the platform in ways that compromise security or fairness\n\nYou may close your account at any time by contacting us.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 12: Limitation of Liability
            _buildTermsCard(
              '12. Limitation of Liability',
              '• Uriel Academy is a study aid, not a guarantee of exam results\n• We are not liable for indirect damages, exam outcomes, or school decisions\n• Our total liability is limited to the subscription fees you paid in the last 3 months',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 13: Changes to Terms
            _buildTermsCard(
              '13. Changes to Terms',
              'We may update these Terms from time to time. If changes are significant, we will notify you via the app, website, or email. Continued use of the Services means you accept the updated Terms.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 14: Governing Law
            _buildTermsCard(
              '14. Governing Law',
              'These Terms are governed by the laws of the Republic of Ghana.',
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCard(String title, String content, bool isSmallScreen, {bool hasPrivacyLink = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasPrivacyLink) ...[
            RichText(
              text: TextSpan(
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
                children: [
                  const TextSpan(text: 'Your privacy is important to us. Please read our '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/privacy'),
                      child: Text(
                        'Privacy Policy',
                        style: GoogleFonts.montserrat(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: const Color(0xFFD62828),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' to understand how we collect, use, and protect your data.'),
                ],
              ),
            ),
          ] else ...[
            Text(
              content,
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isSmallScreen) {
    return Container(
      width: double.infinity,
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
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 800),
          child: Column(
            children: [
              Text(
                '15. Contact Us',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
              
              Text(
                'If you have questions about these Terms, please contact us:',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
              
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Uriel Academy',
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email, color: Colors.white.withOpacity(0.9), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'studywithuriel@gmail.com',
                          style: GoogleFonts.montserrat(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.web, color: Colors.white.withOpacity(0.9), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'www.uriel.academy',
                          style: GoogleFonts.montserrat(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 32 : 40),
              
              Text(
                'Uriel Academy exists to make learning accessible, affordable, and empowering—for every student, parent, and school.',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
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

  Widget _buildFooter(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 24 : 32,
      ),
      color: const Color(0xFF1A1E3F),
      child: Column(
        children: [
          Text(
            'Uriel Academy',
            style: AppStyles.brandNameDark(fontSize: isSmallScreen ? 18 : 20),
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          Text(
            '© 2025 Uriel Academy. Built with ❤️ for Ghanaian students.',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}