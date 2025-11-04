import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../constants/app_styles.dart';
import 'user_management_page.dart';
import 'content_management_page.dart';
import 'feedback_page.dart';
import 'question_collections_page.dart';
import 'revision_page.dart';
import 'generate_quiz_page.dart';
import 'textbooks_page.dart';
import 'trivia_categories_page.dart';
import 'notes_page.dart'; // NotesTab
import 'redesigned_leaderboard_page.dart';
import 'uri_page.dart';
import 'school_admin_students_page.dart';
import 'school_admin_teachers_page.dart';
import 'pricing_page.dart';
import 'payment_page.dart';
import 'terms_of_service.dart';
import 'privacy_policy.dart';
import 'contact.dart';
import 'faq.dart';
import 'redesigned_all_ranks_page.dart';

class RedesignedAdminHomePage extends StatefulWidget {
  const RedesignedAdminHomePage({super.key});

  @override
  State<RedesignedAdminHomePage> createState() => _RedesignedAdminHomePageState();
}

class _RedesignedAdminHomePageState extends State<RedesignedAdminHomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  
  int _selectedIndex = 0;
  bool _showingProfile = false;
  
  // Admin profile data
  String adminName = "";
  String adminRole = "Super Admin";
  String? adminPhotoUrl;
  String? adminPresetAvatar;
  StreamSubscription<DocumentSnapshot>? _adminStreamSubscription;
  
  // Profile form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isEditingPassword = false;
  bool _isLoading = false;
  
  // Admin metrics
  int totalUsers = 0;
  int totalSchools = 0;
  int totalQuestions = 0;
  int activeSubscriptions = 0;
  double systemHealth = 0.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    _loadAdminProfile();
    _loadAdminMetrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _adminStreamSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      _adminStreamSubscription = docRef.snapshots().listen((snapshot) {
        if (!mounted) return;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            adminName = data['displayName'] ?? data['firstName'] ?? 'Admin';
            adminRole = data['role'] == 'admin' ? 'Super Admin' : 'Admin';
            adminPhotoUrl = data['avatar'];
            adminPresetAvatar = data['presetAvatar'];
            
            // Load form data
            _firstNameController.text = data['firstName'] ?? '';
            _lastNameController.text = data['lastName'] ?? '';
            _emailController.text = user.email ?? '';
            _phoneController.text = data['phone'] ?? '';
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
    }
  }

  Future<void> _loadAdminMetrics() async {
    try {
      // Load basic metrics from Firestore
      final usersSnap = await FirebaseFirestore.instance.collection('users').count().get();
      final schoolsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'schoolAdmin')
          .count()
          .get();
      
      setState(() {
        totalUsers = usersSnap.count ?? 0;
        totalSchools = schoolsSnap.count ?? 0;
        systemHealth = 99.8;
      });
    } catch (e) {
      debugPrint('Error loading admin metrics: $e');
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/landing');
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: AppStyles.warmWhite,
      body: Row(
        children: [
          // Sidebar navigation (desktop only)
          if (!isMobile) _buildSidebar(isTablet),
          
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top app bar
                _buildTopBar(isMobile),
                
                // Main content with tabs
                Expanded(
                  child: _showingProfile
                      ? _buildProfilePage()
                      : IndexedStack(
                          index: _selectedIndex,
                          children: _homeChildren(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Mobile bottom navigation
      bottomNavigationBar: isMobile ? _buildBottomNav() : null,
    );
  }

  // Sidebar for desktop
  Widget _buildSidebar(bool isTablet) {
    return Container(
      width: isTablet ? 200 : 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo and title
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Image.asset(
                  'assets/uri.png',
                  width: 40,
                  height: 40,
                ),
                if (!isTablet) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Admin',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.primaryNavy,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          const SizedBox(height: 24),
          
          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in _navItems()) 
                    _buildNavItem(
                      item['index'] as int, 
                      item['label'] as String, 
                      icon: item['icon'] as IconData?,
                      isTablet: isTablet,
                    ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(),
                  ),
                  
                  _buildNavItem(16, 'Pricing', isTablet: isTablet),
                  _buildNavItem(17, 'Payment', isTablet: isTablet),
                  _buildNavItem(18, 'All Ranks', isTablet: isTablet),
                  _buildNavItem(19, 'Terms of Service', isTablet: isTablet),
                  _buildNavItem(20, 'Privacy Policy', isTablet: isTablet),
                  _buildNavItem(21, 'Contact', isTablet: isTablet),
                  _buildNavItem(22, 'FAQ', isTablet: isTablet),
                ],
              ),
            ),
          ),
          
          // Settings & Sign Out
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.grey[600]),
                  title: !isTablet
                      ? Text(
                          'Sign Out',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        )
                      : null,
                  onTap: _handleSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, {IconData? icon, bool isTablet = false}) {
    final isSelected = _selectedIndex == index;
    final isMainNav = index >= 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: !isTablet
            ? Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD62828) : Colors.grey[700],
                ),
                textAlign: TextAlign.left,
              )
            : null,
        selected: isSelected,
        selectedTileColor: const Color(0xFFD62828).withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          if (isMainNav) {
            setState(() {
              _selectedIndex = index;
              _showingProfile = false;
            });
          } else {
            _handleStaticNavigation(title);
          }
        },
      ),
    );
  }

  void _handleStaticNavigation(String title) {
    switch (title) {
      case 'About Us':
        Navigator.pushNamed(context, '/about');
        break;
      case 'Contact':
        Navigator.pushNamed(context, '/contact');
        break;
      case 'Privacy Policy':
        Navigator.pushNamed(context, '/privacy');
        break;
    }
  }

  // Top bar
  Widget _buildTopBar(bool isMobile) {
    return Container(
      height: 70,
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
        child: Row(
          children: [
            if (isMobile) ...[
              Image.asset(
                'assets/uri.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 12),
              Text(
                'Admin',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primaryNavy,
                ),
              ),
            ],
            
            const Spacer(),
            
            // Profile button
            GestureDetector(
              onTap: () {
                setState(() {
                  _showingProfile = !_showingProfile;
                  if (_showingProfile) _selectedIndex = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showingProfile ? const Color(0xFFD62828).withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFD62828),
                      backgroundImage: adminPhotoUrl != null
                          ? CachedNetworkImageProvider(adminPhotoUrl!)
                          : null,
                      child: adminPhotoUrl == null
                          ? Text(
                              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Text(
                        adminName.isNotEmpty ? adminName : 'Admin',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showingProfile ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom navigation for mobile
  Widget _buildBottomNav() {
    final nav = _navItems();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < (nav.length > 5 ? 5 : nav.length); i++)
                _buildBottomNavItem(
                  nav[i]['index'] as int,
                  nav[i]['label'] as String,
                  nav[i]['icon'] as IconData?,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, String label, IconData? icon) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _showingProfile = false;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.dashboard,
              color: isSelected ? const Color(0xFFD62828) : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFFD62828) : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, Object?>> _navItems() {
    return [
      {'index': 0, 'label': 'Dashboard', 'icon': null},
      {'index': 1, 'label': 'Users', 'icon': null},
      {'index': 2, 'label': 'Content', 'icon': null},
      {'index': 3, 'label': 'Analytics', 'icon': null},
      {'index': 4, 'label': 'Monitoring', 'icon': null},
      {'index': 5, 'label': 'Settings', 'icon': null},
      {'index': 6, 'label': 'Questions', 'icon': null},
      {'index': 7, 'label': 'Revision', 'icon': null},
      {'index': 8, 'label': 'Books', 'icon': null},
      {'index': 9, 'label': 'Notes', 'icon': null},
      {'index': 10, 'label': 'Trivia', 'icon': null},
      {'index': 11, 'label': 'Leaderboard', 'icon': null},
      {'index': 12, 'label': 'Ask Uri', 'icon': null},
      {'index': 13, 'label': 'Students', 'icon': null},
      {'index': 14, 'label': 'Teachers', 'icon': null},
      {'index': 15, 'label': 'Generate Quiz', 'icon': null},
      {'index': 23, 'label': 'Feedback', 'icon': null},
    ];
  }

  List<Widget> _homeChildren() {
    return [
      _buildDashboardTab(),                 // 0: Dashboard
      const UserManagementPage(),           // 1: Users
      const ContentManagementPage(),        // 2: Content
      _buildPlaceholderTab('Analytics'),    // 3: Analytics
      _buildPlaceholderTab('Monitoring'),   // 4: Monitoring
      _buildPlaceholderTab('Settings'),     // 5: Settings
      const QuestionCollectionsPage(),      // 6: Questions
      const RevisionPage(),                 // 7: Revision
      const TextbooksPage(),                // 8: Books
      const NotesTab(),                     // 9: Notes
      const TriviaCategoriesPage(),         // 10: Trivia
      const RedesignedLeaderboardPage(),    // 11: Leaderboard
      const UriPage(embedded: true),        // 12: Ask Uri
      const SchoolAdminStudentsPage(),      // 13: Students
      const SchoolAdminTeachersPage(),      // 14: Teachers
      const GenerateQuizPage(),             // 15: Generate Quiz
      const PricingPage(),                  // 16: Pricing
      const PaymentPage(),                  // 17: Payment
      const RedesignedAllRanksPage(),       // 18: All Ranks
      const TermsOfServicePage(),           // 19: Terms of Service
      const PrivacyPolicyPage(),            // 20: Privacy Policy
      const ContactPage(),                  // 21: Contact
      const FAQPage(),                      // 22: FAQ
      const FeedbackPage(),                 // 23: Feedback
    ];
  }
  
  // Placeholder tab for pages not yet implemented
  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '$title Coming Soon',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is under construction',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Dashboard tab
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Text(
            'Welcome back, ${adminName.split(' ').first}!',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppStyles.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s what\'s happening with your platform today.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Metrics cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              final crossAxisCount = isMobile ? 2 : 4;
              
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: isMobile ? 1.5 : 1.8,
                children: [
                  _buildMetricCard('Total Users', totalUsers.toString(), Icons.people, const Color(0xFF2ECC71)),
                  _buildMetricCard('Schools', totalSchools.toString(), Icons.school, const Color(0xFF3498DB)),
                  _buildMetricCard('Questions', totalQuestions.toString(), Icons.quiz, const Color(0xFFF77F00)),
                  _buildMetricCard('System Health', '${systemHealth.toStringAsFixed(1)}%', Icons.health_and_safety, const Color(0xFFD62828)),
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Recent activity section
          Text(
            'Recent Activity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppStyles.primaryNavy,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildActivityItem('New user registered', 'John Doe joined', '2 minutes ago'),
                _buildActivityItem('Content uploaded', 'Math Chapter 5 added', '15 minutes ago'),
                _buildActivityItem('System update', 'Database optimized', '1 hour ago'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primaryNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_active, color: Color(0xFFD62828), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Profile page
  Widget _buildProfilePage() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Container(
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
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppStyles.primaryNavy,
                            backgroundImage: adminPhotoUrl != null
                                ? CachedNetworkImageProvider(adminPhotoUrl!)
                                : null,
                            child: adminPhotoUrl == null
                                ? Text(
                                    _firstNameController.text.isNotEmpty
                                        ? _firstNameController.text[0]
                                            .toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_firstNameController.text} ${_lastNameController.text}',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  adminRole,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Section
                    _buildSectionCard(
                      title: 'Personal Information',
                      children: [
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _firstNameController,
                                      label: 'First Name',
                                      icon: Icons.person,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter first name';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _lastNameController,
                                      label: 'Last Name',
                                      icon: Icons.person_outline,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter last name';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email,
                                enabled: false,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                icon: Icons.phone,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppStyles.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Save Changes',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Security Section
                    _buildSectionCard(
                      title: 'Security',
                      children: [
                        if (!_isEditingPassword) ...[
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _isEditingPassword = true;
                            }),
                            icon: const Icon(Icons.lock),
                            label: Text(
                              'Change Password',
                              style: GoogleFonts.montserrat(),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: AppStyles.primaryNavy,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ] else ...[
                          _buildTextField(
                            controller: _currentPasswordController,
                            label: 'Current Password',
                            icon: Icons.lock_outline,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _newPasswordController,
                            label: 'New Password',
                            icon: Icons.lock,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm New Password',
                            icon: Icons.lock,
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() {
                                    _isEditingPassword = false;
                                    _currentPasswordController.clear();
                                    _newPasswordController.clear();
                                    _confirmPasswordController.clear();
                                  }),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.montserrat(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppStyles.primaryNavy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Update Password',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Sign out button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _handleSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD62828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
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
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? AppStyles.warmWhite : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppStyles.primaryNavy),
        ),
      ),
      style: GoogleFonts.montserrat(),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'displayName':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating profile: $e',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Passwords do not match',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password must be at least 6 characters',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password updated successfully',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _isEditingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error changing password: ${e.toString()}',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
