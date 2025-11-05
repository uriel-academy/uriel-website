import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_styles.dart';
import '../utils/navigation_helper.dart';
import 'sign_up.dart';
import 'contact.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Questions';
  String _searchQuery = '';
  
  final List<String> _categories = [
    'All Questions',
    'Getting Started', 
    'Account & Billing',
    'Learning Features',
    'Technical Support',
    'For Parents',
    'For Teachers',
    'For Schools',
  ];
  
  final List<Map<String, dynamic>> _allFAQs = [
    // Getting Started
    {
      'category': 'Getting Started',
      'question': 'What is Uriel Academy?',
      'answer': 'Uriel Academy is your all-in-one learning app for BECE and WASSCE prep. You\'ll find past questions, NACCA-approved textbooks, AI-powered help, mock exams, revision plans, and even a fun mascot (Uri!) to keep you motivated.',
      'popular': true,
    },
    {
      'category': 'Getting Started',
      'question': 'Who can use Uriel Academy?',
      'answer': 'Uriel Academy is designed for JHS and SHS students preparing for BECE and WASSCE exams. It\'s also useful for teachers, parents, and school administrators who want to support student learning.',
      'popular': true,
    },
    {
      'category': 'Getting Started',
      'question': 'How do I create an account?',
      'answer': 'Click "Get Started" on our homepage, then choose to sign up with your email, phone number, or Google account. Students under 18 must provide a parent/guardian contact for progress updates.',
      'popular': true,
    },
    {
      'category': 'Getting Started',
      'question': 'What do I need to get started?',
      'answer': 'Just a smartphone or computer with internet access. You can download content for offline use later. No special equipment needed!',
      'popular': false,
    },
    {
      'category': 'Getting Started',
      'question': 'Is Uriel Academy available on mobile?',
      'answer': 'Yes! Uriel is mobile-first, meaning it\'s designed to work smoothly on any smartphone. You don\'t need a laptop or desktop computer.',
      'popular': false,
    },
    {
      'category': 'Getting Started',
      'question': 'Do I need internet to use Uriel Academy?',
      'answer': 'No. You can download question packs, textbooks, and notes for offline use. Perfect for when data is low or you\'re in an area with poor network coverage.',
      'popular': true,
    },
    {
      'category': 'Getting Started',
      'question': 'What exams does Uriel Academy cover?',
      'answer': 'We cover BECE (Basic Education Certificate Examination) for JHS students and WASSCE (West African Senior School Certificate Examination) for SHS students, with all core and elective subjects.',
      'popular': false,
    },
    
    // Account & Billing
    {
      'category': 'Account & Billing',
      'question': 'How much does it cost?',
      'answer': 'We keep it affordable! You can subscribe weekly (from GHS 2.99), bi-weekly, monthly, or yearly. The longer the plan, the more you save. We also offer student and school discounts.',
      'popular': true,
    },
    {
      'category': 'Account & Billing',
      'question': 'What payment methods do you accept?',
      'answer': 'We accept Mobile Money (MTN, Vodafone, AirtelTigo), Visa/Mastercard, and bank transfers through our secure Paystack integration.',
      'popular': true,
    },
    {
      'category': 'Account & Billing',
      'question': 'How do I change my subscription plan?',
      'answer': 'Go to your Profile > Subscription Settings to upgrade, downgrade, or change your billing cycle. Changes take effect immediately, and you\'ll be charged the prorated difference.',
      'popular': false,
    },
    {
      'category': 'Account & Billing',
      'question': 'Can I get a refund?',
      'answer': 'Refunds are processed within 7 days of purchase if you haven\'t accessed premium content. Contact our support team with your subscription details for assistance.',
      'popular': false,
    },
    {
      'category': 'Account & Billing',
      'question': 'How do I reset my password?',
      'answer': 'Click "Forgot Password" on the sign-in page, enter your email, and follow the instructions sent to your inbox. If you don\'t see the email, check your spam folder.',
      'popular': true,
    },
    {
      'category': 'Account & Billing',
      'question': 'Is there a free trial available?',
      'answer': 'Yes! New users get a 7-day free trial with access to all premium features. No credit card required to start your trial.',
      'popular': false,
    },
    
    // Learning Features
    {
      'category': 'Learning Features',
      'question': 'How many past questions are available?',
      'answer': 'We have over 10,000 past questions covering BECE and WASSCE from the last 15 years, all with detailed solutions and explanations.',
      'popular': true,
    },
    {
      'category': 'Learning Features',
      'question': 'How does the AI tutor work?',
      'answer': 'Our AI assistant helps with explanations, creates personalized study plans, answers your questions, and even works in local languages like Twi, Ga, Ewe, and Hausa. It\'s available 24/7 for premium users.',
      'popular': true,
    },
    {
      'category': 'Learning Features',
      'question': 'Can I download textbooks for offline reading?',
      'answer': 'Yes! Premium subscribers can download NACCA-approved textbooks and study materials for offline reading. Perfect for studying without internet.',
      'popular': false,
    },
    {
      'category': 'Learning Features',
      'question': 'How does progress tracking work?',
      'answer': 'Uriel tracks your study time, quiz scores, weak areas, and improvements automatically. You can view detailed analytics in your dashboard, and parents receive weekly progress reports.',
      'popular': false,
    },
    {
      'category': 'Learning Features',
      'question': 'What is "Calm Learning Mode"?',
      'answer': 'It\'s a distraction-free study space with gentle reminders, motivational messages, and reflection prompts—designed to keep you focused and stress-free, especially before exams.',
      'popular': false,
    },
    {
      'category': 'Learning Features',
      'question': 'Are answers and explanations provided?',
      'answer': 'Yes! Every question comes with detailed step-by-step solutions and explanations to help you understand the concepts, not just memorize answers.',
      'popular': false,
    },
    
    // Technical Support
    {
      'category': 'Technical Support',
      'question': 'What devices can I use Uriel Academy on?',
      'answer': 'Uriel works on smartphones, tablets, laptops, and desktop computers. It\'s compatible with Android, iOS, Windows, Mac, and works in any modern web browser.',
      'popular': false,
    },
    {
      'category': 'Technical Support',
      'question': 'Why is the app/website running slowly?',
      'answer': 'This could be due to poor internet connection, low device storage, or browser cache issues. Try clearing your browser cache, closing other apps, or switching to a better network.',
      'popular': false,
    },
    {
      'category': 'Technical Support',
      'question': 'I\'m having trouble logging in, what should I do?',
      'answer': 'First, check that you\'re using the correct email and password. If you\'ve forgotten your password, use the "Reset Password" option. If problems persist, contact our support team.',
      'popular': false,
    },
    {
      'category': 'Technical Support',
      'question': 'Is my data secure?',
      'answer': 'Yes! We use industry-standard encryption, secure cloud storage (Firebase), role-based access controls, and comply with Ghana\'s Data Protection Act. Your personal information is safe with us.',
      'popular': true,
    },
    
    // For Parents
    {
      'category': 'For Parents',
      'question': 'How can I monitor my child\'s progress?',
      'answer': 'You\'ll receive weekly progress reports via email or WhatsApp showing study time, quiz scores, strong/weak subjects, and improvement recommendations. No separate login required!',
      'popular': true,
    },
    {
      'category': 'For Parents',
      'question': 'Do I need to create an account to track my child?',
      'answer': 'No. When your child signs up, they\'ll add your email and/or WhatsApp number, and you\'ll automatically receive progress updates. Simple and convenient!',
      'popular': false,
    },
    {
      'category': 'For Parents',
      'question': 'Is the content safe for children?',
      'answer': 'Absolutely. All content is educational, curriculum-aligned, and age-appropriate. We include wellness features like break reminders and calm study modes to promote healthy learning habits.',
      'popular': false,
    },
    {
      'category': 'For Parents',
      'question': 'Can I pay for my child\'s subscription?',
      'answer': 'Yes! Parents can pay directly via mobile money, debit/credit card, or bank transfer. You can manage the subscription from your child\'s account settings.',
      'popular': false,
    },
    
    // For Teachers
    {
      'category': 'For Teachers',
      'question': 'How can teachers use Uriel Academy?',
      'answer': 'Teachers can recommend Uriel as a study companion, use our question database for class practice, assign homework, and view student performance insights when linked through a school account.',
      'popular': false,
    },
    {
      'category': 'For Teachers',
      'question': 'Can I assign homework using Uriel?',
      'answer': 'Yes! Teachers with school accounts can assign specific question sets, mock exams, or topics to students and track completion rates and performance.',
      'popular': false,
    },
    {
      'category': 'For Teachers',
      'question': 'Does Uriel replace teachers?',
      'answer': 'Not at all! Uriel supports teachers by providing additional practice materials and progress tracking. Students still need your guidance, expertise, and classroom instruction.',
      'popular': false,
    },
    
    // For Schools
    {
      'category': 'For Schools',
      'question': 'What are the benefits of a school subscription?',
      'answer': 'Schools get bulk pricing, admin dashboards, student management tools, performance analytics, teacher accounts, and revenue sharing opportunities. Plus priority support for implementation.',
      'popular': false,
    },
    {
      'category': 'For Schools',
      'question': 'How does institutional pricing work?',
      'answer': 'We offer significant discounts for schools based on student enrollment numbers. Contact us for a custom quote and demo tailored to your institution\'s needs.',
      'popular': false,
    },
    {
      'category': 'For Schools',
      'question': 'Can we get a demo for our school?',
      'answer': 'Absolutely! We provide free demos, training sessions for teachers, and implementation support. Contact our team to schedule a presentation for your school leadership.',
      'popular': false,
    },
  ];
  
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
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFAQs {
    var faqs = _allFAQs;
    
    // Filter by category
    if (_selectedCategory != 'All Questions') {
      faqs = faqs.where((faq) => faq['category'] == _selectedCategory).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      faqs = faqs.where((faq) => 
        faq['question'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        faq['answer'].toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return faqs;
  }
  
  List<Map<String, dynamic>> get _popularFAQs {
    return _allFAQs.where((faq) => faq['popular'] == true).take(6).toList();
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
            
            // Search Bar
            _buildSearchSection(isSmallScreen),
            
            // Popular Questions
            if (_searchQuery.isEmpty && _selectedCategory == 'All Questions')
              _buildPopularQuestions(isSmallScreen),
            
            // Category Navigation
            _buildCategoryNavigation(isSmallScreen),
            
            // FAQ Content
            _buildFAQContent(isSmallScreen),
            
            // Still Need Help
            _buildHelpSection(isSmallScreen),
            
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
                    'Frequently Asked Questions',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: isSmallScreen ? 32 : 48,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  
                  Text(
                    'Find answers to common questions about Uriel Academy. Can\'t find what you\'re looking for? Contact our support team.',
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

  Widget _buildSearchSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 20 : 30,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 600),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search for answers...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFFD62828)),
            suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularQuestions(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 20 : 30,
      ),
      color: Colors.grey[50],
      child: Column(
        children: [
          Text(
            'Most Asked Questions',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 24),
          
          if (isSmallScreen) ...[
            // Mobile: Use ListView instead of GridView for better content display
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _popularFAQs.length,
              itemBuilder: (context, index) {
                final faq = _popularFAQs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPopularFAQCard(faq, isSmallScreen),
                );
              },
            ),
          ] else ...[
            // Desktop: Keep GridView
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _popularFAQs.length,
              itemBuilder: (context, index) {
                final faq = _popularFAQs[index];
                return _buildPopularFAQCard(faq, isSmallScreen);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularFAQCard(Map<String, dynamic> faq, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'POPULAR',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            faq['question'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
            maxLines: isSmallScreen ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            faq['answer'],
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            maxLines: isSmallScreen ? 4 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryNavigation(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSmallScreen) ...[
            // Dropdown for mobile
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ] else ...[
            // Pills for desktop
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD62828) : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD62828) : Colors.grey[300]!,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: const Color(0xFFD62828).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAQContent(bool isSmallScreen) {
    final filteredFAQs = _filteredFAQs;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 20 : 30,
      ),
      child: Column(
        children: [
          if (filteredFAQs.isEmpty) ...[
            _buildNoResultsWidget(isSmallScreen),
          ] else ...[
            // Results count
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filteredFAQs.length} question${filteredFAQs.length != 1 ? 's' : ''} found',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // FAQ List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFAQs.length,
              itemBuilder: (context, index) {
                return _buildFAQItem(filteredFAQs[index], isSmallScreen);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAQItem(Map<String, dynamic> faq, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 20,
            vertical: 8,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            isSmallScreen ? 16 : 20,
            0,
            isSmallScreen ? 16 : 20,
            isSmallScreen ? 16 : 20,
          ),
          title: Row(
            children: [
              if (faq['popular'] == true) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'POPULAR',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD62828),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  faq['question'],
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ),
            ],
          ),
          iconColor: const Color(0xFFD62828),
          collapsedIconColor: Colors.grey[600],
          children: [
            Text(
              faq['answer'],
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 15,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Was this helpful?',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _showFeedback('Yes'),
                  icon: const Icon(Icons.thumb_up_outlined, size: 18),
                  color: Colors.grey[600],
                ),
                IconButton(
                  onPressed: () => _showFeedback('No'),
                  icon: const Icon(Icons.thumb_down_outlined, size: 18),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 32 : 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: isSmallScreen ? 64 : 80,
            color: Colors.grey[400],
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          Text(
            'No results found',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Try adjusting your search terms or browse by category',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Contact Support',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(bool isSmallScreen) {
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
                'Didn\'t Find Your Answer?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 20),
              
              Text(
                'Our support team is here to help you succeed',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 32 : 40),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isSmallScreen ? 1 : 2,
                childAspectRatio: isSmallScreen ? 3 : 2.5,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildHelpCard(
                    'Contact Support',
                    'Get personalized help',
                    'studywithuriel@gmail.com',
                    Icons.email_outlined,
                    isSmallScreen,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactPage()),
                    ),
                  ),
                  _buildHelpCard(
                    'WhatsApp Us',
                    'Quick chat support',
                    '+233 24 731 7076',
                    Icons.phone_outlined,
                    isSmallScreen,
                    () => _launchWhatsApp(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCard(String title, String subtitle, String contact, 
      IconData icon, bool isSmallScreen, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact,
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
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

  void _showFeedback(String response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your feedback!'),
        backgroundColor: Color(0xFF1A1E3F),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _launchWhatsApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp would open here: +233 24 731 7076'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }
}