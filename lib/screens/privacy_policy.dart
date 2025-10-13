import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_styles.dart';
import 'sign_up.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> with TickerProviderStateMixin {
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
            
            // Policy Content
            _buildPolicyContent(isSmallScreen),
            
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
            onTap: () {
              // If user is logged in, go to home, otherwise go to landing
              final isLoggedIn = FirebaseAuth.instance.currentUser != null;
              Navigator.pushReplacementNamed(
                context, 
                isLoggedIn ? '/home' : '/landing',
              );
            },
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
                    'Privacy Policy',
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
                      color: const Color(0xFFD62828).withValues(alpha: 0.1),
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
                    'Uriel Academy is committed to protecting your privacy. This Privacy Policy explains how we collect, use, store, and safeguard your personal information when you use our platform.',
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

  Widget _buildPolicyContent(bool isSmallScreen) {
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
            _buildPolicyCard(
              '',
              'By using Uriel Academy, you agree to the practices described in this Privacy Policy.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 1: Information We Collect
            _buildPolicyCard(
              '1. Information We Collect',
              'We collect the following types of information:',
              isSmallScreen,
            ),
            
            const SizedBox(height: 16),
            
            _buildSubSection(
              'a. Personal Information (provided by you)',
              '• Name, email, phone number, and school details (when creating an account)\n• Parent/guardian email or WhatsApp number (for student progress updates)\n• Payment information (processed securely through third-party providers like Paystack)',
              isSmallScreen,
            ),
            
            const SizedBox(height: 16),
            
            _buildSubSection(
              'b. Usage Information (collected automatically)',
              '• Device type, browser, operating system, and IP address\n• App usage data (pages visited, features used, study activity, quiz attempts)',
              isSmallScreen,
            ),
            
            const SizedBox(height: 16),
            
            _buildSubSection(
              'c. Academic Information',
              '• Subjects studied, scores, test performance, and progress history\n• School-related data when students are linked to a school account',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 2: How We Use Your Information
            _buildPolicyCard(
              '2. How We Use Your Information',
              'We use your information to:\n\n• Provide and improve our learning services\n• Track progress, generate reports, and personalize learning journeys\n• Send parents/guardians weekly or monthly progress updates\n• Enable schools and admins to manage student performance at scale\n• Process payments securely\n• Provide customer support and respond to inquiries\n• Ensure platform security and prevent misuse\n\nWe do not sell your personal information to third parties.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 3: Sharing of Information
            _buildPolicyCard(
              '3. Sharing of Information',
              'We may share information only in these cases:\n\n• With Parents/Guardians: Progress updates sent via email/WhatsApp\n• With Schools/Admins: When a student is linked to a school account\n• With Service Providers: Secure partners for payments, hosting, cloud storage, and communication\n• For Legal Reasons: If required by law, regulation, or to protect rights and safety',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 4: Data Storage & Security
            _buildPolicyCard(
              '4. Data Storage & Security',
              '• All data is stored securely in encrypted databases (e.g., Firebase)\n• Access is role-based (students, parents, school admins, staff)\n• Two-factor authentication (2FA/OTP) may be used for extra protection\n• Regular backups are maintained to prevent data loss',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 5: Student Privacy & Parental Consent
            _buildPolicyCard(
              '5. Student Privacy & Parental Consent',
              '• Students under 18 must provide parent/guardian contact information\n• Parents receive performance updates automatically\n• We comply with Ghana\'s Data Protection Act, 2012 (Act 843) and global best practices for safeguarding minors online',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 6: Your Choices & Rights
            _buildPolicyCard(
              '6. Your Choices & Rights',
              'You have the right to:\n\n• Access and update your personal information\n• Request deletion of your account and data\n• Opt out of non-essential notifications\n• Contact us with questions or complaints about data handling',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 7: Cookies & Tracking
            _buildPolicyCard(
              '7. Cookies & Tracking',
              'We may use cookies or similar technologies to improve your experience. You can disable cookies in your browser, but some features may not work properly.',
              isSmallScreen,
            ),
            
            const SizedBox(height: 24),
            
            // Section 8: Changes to This Policy
            _buildPolicyCard(
              '8. Changes to This Policy',
              'We may update this Privacy Policy from time to time. If we make significant changes, we\'ll notify you through the app, website, or email.',
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(String title, String content, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          Text(
            content,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSection(String title, String content, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      margin: EdgeInsets.only(left: isSmallScreen ? 0 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 16 : 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
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
                '9. Contact Us',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
              
              Text(
                'If you have any questions about this Privacy Policy or your data, please contact us:',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
              
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                        Icon(Icons.email, color: Colors.white.withValues(alpha: 0.9), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'studywithuriel@gmail.com',
                          style: GoogleFonts.montserrat(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.web, color: Colors.white.withValues(alpha: 0.9), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'www.uriel.academy',
                          style: GoogleFonts.montserrat(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isSmallScreen ? 32 : 40),
              
              Text(
                'At Uriel Academy, your learning journey is safe, private, and protected.',
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
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}