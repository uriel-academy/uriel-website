import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_styles.dart';
import '../widgets/common_footer.dart';
import '../utils/navigation_helper.dart';
import 'sign_up.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedUserType = 'Student';
  String _selectedInquiryType = 'General Question';
  bool _isSubmitting = false;
  bool _formSubmitted = false;
  bool _captchaVerified = false;
  
  final List<String> _userTypes = [
    'Student', 'Teacher', 'School', 'Parent', 'Other'
  ];
  
  final List<String> _inquiryTypes = [
    'Technical Support', 'Billing & Payments', 'Account Issues', 
    'Feature Request', 'Partnership Inquiry', 'General Question', 'Report a Problem'
  ];
  
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I reset my password?',
      'answer': 'Click "Forgot Password" on the sign-in page, enter your email, and follow the instructions sent to your inbox. If you don\'t see the email, check your spam folder.'
    },
    {
      'question': 'What payment methods do you accept?',
      'answer': 'We accept Mobile Money (MTN, Vodafone, AirtelTigo), Visa/Mastercard, and bank transfers through our secure Paystack integration.'
    },
    {
      'question': 'How do I change my subscription plan?',
      'answer': 'Go to your Profile > Subscription Settings to upgrade, downgrade, or change your billing cycle. Changes take effect immediately.'
    },
    {
      'question': 'Can I get a refund?',
      'answer': 'Refunds are processed within 7 days of purchase if you haven\'t accessed premium content. Contact support with your subscription details.'
    },
    {
      'question': 'How do I access past questions?',
      'answer': 'Premium subscribers can access past questions in the Study section. Filter by subject, year, and exam type (BECE/WASSCE).'
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes! We use industry-standard encryption and secure cloud storage. Read our Privacy Policy for detailed information about data protection.'
    },
    {
      'question': 'How does the AI tutor work?',
      'answer': 'Our AI assistant helps with explanations, study plans, and answers questions in English or local languages. It\'s available 24/7 for premium users.'
    },
    {
      'question': 'Can parents track student progress?',
      'answer': 'Yes! Parents receive weekly progress reports via email/WhatsApp with study time, quiz scores, and improvement recommendations.'
    },
    {
      'question': 'Do you offer school/institutional plans?',
      'answer': 'Yes! We have special pricing for schools with bulk student management, teacher dashboards, and detailed analytics. Contact us for a quote.'
    },
    {
      'question': 'How often is content updated?',
      'answer': 'We update past questions immediately after each exam cycle and add new textbook content monthly based on NACCA curriculum changes.'
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
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
            
            // Contact Options Grid
            _buildContactOptions(isSmallScreen),
            
            // Contact Form
            _buildContactForm(isSmallScreen),
            
            // FAQ Section
            _buildFAQSection(isSmallScreen),
            
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
                    'We\'re Here to Help',
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
                    'Have questions? We\'d love to hear from you. Send us a message and we\'ll respond as soon as possible.',
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

  Widget _buildContactOptions(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 20 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 1000),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isSmallScreen ? 1 : 2,
          childAspectRatio: isSmallScreen ? 2.5 : 2.2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          children: [
            _buildContactCard(
              'Email Us',
              'info@uriel.academy',
              'Within 24 hours',
              Icons.email_outlined,
              const Color(0xFF2196F3),
              isSmallScreen,
              () => _launchEmail(),
            ),
            _buildContactCard(
              'Call/WhatsApp',
              '+233 24 731 7076',
              'Mon-Fri, 8am-6pm GMT',
              Icons.phone_outlined,
              const Color(0xFF4CAF50),
              isSmallScreen,
              () => _launchWhatsApp(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String title, String contact, String availability, 
      IconData icon, Color color, bool isSmallScreen, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
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
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact,
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 14 : 15,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    availability,
                    style: GoogleFonts.montserrat(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      color: Colors.grey[50],
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send Us a Message',
                style: GoogleFonts.playfairDisplay(
                  fontSize: isSmallScreen ? 28 : 36,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isSmallScreen ? 24 : 32),
              
              if (_formSubmitted) ...[
                _buildSuccessMessage(isSmallScreen),
                const SizedBox(height: 24),
              ],
              
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Field
                      _buildFormField(
                        'Full Name',
                        _nameController,
                        'Please enter your full name',
                        isRequired: true,
                        isSmallScreen: isSmallScreen,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Email Field
                      _buildFormField(
                        'Email Address',
                        _emailController,
                        'Please enter a valid email address',
                        inputType: TextInputType.emailAddress,
                        isRequired: true,
                        isSmallScreen: isSmallScreen,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Phone Field
                      _buildFormField(
                        'Phone Number (Optional)',
                        _phoneController,
                        null,
                        inputType: TextInputType.phone,
                        isSmallScreen: isSmallScreen,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // User Type Dropdown
                      _buildDropdownField(
                        'User Type',
                        _selectedUserType,
                        _userTypes,
                        (value) => setState(() => _selectedUserType = value!),
                        isSmallScreen,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Inquiry Type Dropdown
                      _buildDropdownField(
                        'Subject/Inquiry Type',
                        _selectedInquiryType,
                        _inquiryTypes,
                        (value) => setState(() => _selectedInquiryType = value!),
                        isSmallScreen,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Message Field
                      _buildMessageField(isSmallScreen),
                      
                      const SizedBox(height: 24),
                      
                      // CAPTCHA
                      _buildCaptcha(isSmallScreen),
                      
                      const SizedBox(height: 32),
                      
                      // Submit Button
                      _buildSubmitButton(isSmallScreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String? errorMessage,
      {TextInputType inputType = TextInputType.text, bool isRequired = false, required bool isSmallScreen}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: GoogleFonts.montserrat(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return errorMessage;
            }
            if (inputType == TextInputType.emailAddress && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          } : null,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, 
      ValueChanged<String?> onChanged, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: GoogleFonts.montserrat(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message *',
          style: GoogleFonts.montserrat(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _messageController,
          maxLines: 6,
          maxLength: 1000,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your message';
            }
            if (value.length < 10) {
              return 'Message must be at least 10 characters long';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Tell us about your question or issue...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD62828), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterText: '${_messageController.text.length}/1000',
          ),
        ),
      ],
    );
  }

  Widget _buildCaptcha(bool isSmallScreen) {
    return Row(
      children: [
        Checkbox(
          value: _captchaVerified,
          onChanged: (value) => setState(() => _captchaVerified = value ?? false),
          activeColor: const Color(0xFFD62828),
        ),
        Expanded(
          child: Text(
            'I\'m not a robot',
            style: GoogleFonts.montserrat(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting || !_captchaVerified ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD62828),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'Send Message',
                style: GoogleFonts.montserrat(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessMessage(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Sent Successfully!',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thank you for contacting us. We\'ll get back to you within 24 hours.',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 14 : 15,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 32,
        vertical: isSmallScreen ? 40 : 60,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: isSmallScreen ? double.infinity : 900),
        child: Column(
          children: [
            Text(
              'Quick Answers',
              style: GoogleFonts.playfairDisplay(
                fontSize: isSmallScreen ? 28 : 36,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 16 : 20),
            
            Text(
              'Find answers to common questions before reaching out',
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 16 : 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isSmallScreen ? 32 : 40),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _faqs.length,
              itemBuilder: (context, index) {
                return _buildFAQItem(index, isSmallScreen);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(int index, bool isSmallScreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: ExpansionTile(
        title: Text(
          _faqs[index]['question']!,
          style: GoogleFonts.montserrat(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Text(
              _faqs[index]['answer']!,
              style: GoogleFonts.montserrat(
                fontSize: isSmallScreen ? 14 : 15,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _captchaVerified) {
      setState(() => _isSubmitting = true);
      
      // Send email with form data
      await _sendContactEmail();
      
      // Simulate form submission
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isSubmitting = false;
        _formSubmitted = true;
      });
      
      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _messageController.clear();
      _selectedUserType = 'Student';
      _selectedInquiryType = 'General Question';
      _captchaVerified = false;
    }
  }

  Future<void> _sendContactEmail() async {
    final emailBody = '''
Contact Form Submission from ${_nameController.text.trim()}

Name: ${_nameController.text.trim()}
Email: ${_emailController.text.trim()}
Phone: ${_phoneController.text.isNotEmpty ? _phoneController.text.trim() : 'Not provided'}
User Type: $_selectedUserType
Inquiry Type: $_selectedInquiryType

Message:
${_messageController.text.trim()}
    '''.trim();

    final emailUri = Uri(
      scheme: 'mailto',
      path: 'info@uriel.academy',
      query: 'subject=${Uri.encodeComponent('Contact: $_selectedInquiryType from ${_nameController.text.trim()}')}&body=${Uri.encodeComponent(emailBody)}',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    } catch (e) {
      // Email launch failed, but form still submitted
      debugPrint('Could not launch email: $e');
    }
  }

  void _launchEmail() async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'info@uriel.academy',
      query: 'subject=${Uri.encodeComponent('Contact from Uriel Academy')}&body=${Uri.encodeComponent('Hi, I would like to get in touch...')}',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email client'),
              backgroundColor: Color(0xFFD62828),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening email client'),
            backgroundColor: Color(0xFFD62828),
          ),
        );
      }
    }
  }

  void _launchWhatsApp() async {
    final whatsappUri = Uri.parse('https://wa.me/233247317076?text=${Uri.encodeComponent('Hi, I would like to get in touch...')}');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp'),
              backgroundColor: Color(0xFFD62828),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening WhatsApp'),
            backgroundColor: Color(0xFFD62828),
          ),
        );
      }
    }
  }
}