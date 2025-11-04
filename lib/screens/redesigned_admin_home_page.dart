import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../constants/app_styles.dart';
import '../services/auth_service.dart';
import 'user_management_page.dart';
import 'content_management_page.dart';
import 'feedback_page.dart';

class RedesignedAdminHomePage extends StatefulWidget {
  const RedesignedAdminHomePage({super.key});

  @override
  State<RedesignedAdminHomePage> createState() => _RedesignedAdminHomePageState();
}

class _RedesignedAdminHomePageState extends State<RedesignedAdminHomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _selectedIndex = 0;
  bool _showingProfile = false;
  
  // Admin profile data
  String adminName = "";
  String adminRole = "Super Admin";
  String? adminPhotoUrl;
  String? adminPresetAvatar;
  StreamSubscription<DocumentSnapshot>? _adminStreamSubscription;
  
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
    _loadAdminProfile();
    _loadAdminMetrics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _adminStreamSubscription?.cancel();
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD62828), Color(0xFFF77F00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
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
                  
                  _buildNavItem(-1, 'About Us', isTablet: isTablet),
                  _buildNavItem(-2, 'Contact', isTablet: isTablet),
                  _buildNavItem(-3, 'Privacy Policy', isTablet: isTablet),
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
        leading: icon != null ? Icon(icon, color: isSelected ? const Color(0xFFD62828) : Colors.grey[600]) : null,
        title: !isTablet
            ? Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFD62828) : Colors.grey[700],
                ),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD62828), Color(0xFFF77F00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
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
            ] else ...[
              Text(
                _getPageTitle(),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primaryNavy,
                ),
              ),
            ],
            
            const Spacer(),
            
            // Notifications icon
            IconButton(
              icon: Badge(
                label: const Text('3'),
                child: Icon(Icons.notifications_outlined, color: Colors.grey[700]),
              ),
              onPressed: () {
                // TODO: Show notifications
              },
            ),
            
            const SizedBox(width: 8),
            
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

  String _getPageTitle() {
    if (_showingProfile) return 'Profile Settings';
    final items = _navItems();
    if (_selectedIndex >= 0 && _selectedIndex < items.length) {
      return items[_selectedIndex]['label'] as String;
    }
    return 'Dashboard';
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
      {'index': 0, 'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
      {'index': 1, 'label': 'Users', 'icon': Icons.people_outline},
      {'index': 2, 'label': 'Content', 'icon': Icons.library_books_outlined},
      {'index': 3, 'label': 'Analytics', 'icon': Icons.analytics_outlined},
      {'index': 4, 'label': 'Monitoring', 'icon': Icons.monitor_heart_outlined},
      {'index': 5, 'label': 'Settings', 'icon': Icons.settings_outlined},
      {'index': 6, 'label': 'Feedback', 'icon': Icons.feedback_outlined},
    ];
  }

  List<Widget> _homeChildren() {
    return [
      _buildDashboardTab(),       // 0: Dashboard
      const UserManagementPage(), // 1: Users
      const ContentManagementPage(), // 2: Content
      _buildPlaceholderTab('Analytics'), // 3: Analytics
      _buildPlaceholderTab('Monitoring'), // 4: Monitoring
      _buildPlaceholderTab('Settings'), // 5: Settings
      const FeedbackPage(),       // 6: Feedback
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFFD62828),
                  backgroundImage: adminPhotoUrl != null
                      ? CachedNetworkImageProvider(adminPhotoUrl!)
                      : null,
                  child: adminPhotoUrl == null
                      ? Text(
                          adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                          style: GoogleFonts.montserrat(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Admin',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.primaryNavy,
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
          
          const SizedBox(height: 32),
          
          // Profile settings sections
          _buildProfileSection(
            'Account Settings',
            [
              _buildProfileItem(Icons.person_outline, 'Edit Profile', () {}),
              _buildProfileItem(Icons.lock_outline, 'Change Password', () {}),
              _buildProfileItem(Icons.email_outlined, 'Email Preferences', () {}),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildProfileSection(
            'System',
            [
              _buildProfileItem(Icons.notifications_outlined, 'Notifications', () {}),
              _buildProfileItem(Icons.security_outlined, 'Security', () {}),
              _buildProfileItem(Icons.backup_outlined, 'Backup & Restore', () {}),
            ],
          ),
          
          const SizedBox(height: 24),
          
          _buildProfileSection(
            'Support',
            [
              _buildProfileItem(Icons.help_outline, 'Help Center', () {}),
              _buildProfileItem(Icons.description_outlined, 'Documentation', () {}),
              _buildProfileItem(Icons.bug_report_outlined, 'Report Issue', () {}),
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
    );
  }

  Widget _buildProfileSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppStyles.primaryNavy,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFD62828)),
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppStyles.primaryNavy,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
