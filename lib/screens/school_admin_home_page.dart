import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../constants/app_styles.dart';
import '../services/connection_service.dart';
import '../services/auth_service.dart';
import 'textbooks_page.dart';
import 'feedback_page.dart';
import 'trivia_categories_page.dart';
import 'school_admin_dashboard.dart';
import 'school_admin_students_page.dart';
import 'school_admin_teachers_page.dart';
import 'school_admin_profile_page.dart';
import 'redesigned_leaderboard_page.dart';
import 'uri_page.dart';

class SchoolAdminHomePage extends StatefulWidget {
  const SchoolAdminHomePage({super.key});

  @override
  State<SchoolAdminHomePage> createState() => _SchoolAdminHomePageState();
}

class _SchoolAdminHomePageState extends State<SchoolAdminHomePage> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late AnimationController _animationController;
  
  int _selectedIndex = 0;
  bool _showingProfile = false;
  
  // User profile data
  String userName = "";
  String schoolName = "";
  String? userPhotoUrl;
  String? userPresetAvatar;
  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 7, vsync: this); // 7 tabs for school admin
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    
    _loadUserData();
    _setupUserStream();
  }
  
  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          userName = data['displayName'] ?? 
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
          schoolName = data['school'] ?? 'School Admin';
          userPhotoUrl = data['photoURL'];
          userPresetAvatar = data['presetAvatar'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  void _setupUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _userStreamSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          userName = data['displayName'] ?? 
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
          schoolName = data['school'] ?? 'School Admin';
          userPhotoUrl = data['photoURL'];
          userPresetAvatar = data['presetAvatar'];
        });
      }
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _animationController.dispose();
    _userStreamSubscription?.cancel();
    super.dispose();
  }

  ImageProvider? _getAvatarImage() {
    if (userPhotoUrl != null && userPhotoUrl!.isNotEmpty) {
      return NetworkImage(userPhotoUrl!);
    } else if (userPresetAvatar != null && userPresetAvatar!.isNotEmpty) {
      return AssetImage(userPresetAvatar!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            child: Stack(
              children: [
                // Main Content
                isSmallScreen
                    ? Column(
                        children: [
                          // Mobile Header
                          _buildMobileHeader(),
                          
                          // Mobile Content
                          Expanded(
                            child: _showingProfile 
                                ? const SchoolAdminProfilePage()
                                : IndexedStack(
                                    index: _selectedIndex,
                                    children: _homeChildren(),
                                  ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Desktop Sidebar Navigation
                          _buildSideNavigation(),
                          
                          // Desktop Main Content
                          Expanded(
                            child: Column(
                              children: [
                                // Desktop Header
                                _buildHeader(context),
                                
                                // Desktop Content Area
                                Expanded(
                                  child: _showingProfile 
                                      ? const SchoolAdminProfilePage()
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
                
                // Connection Status Indicator
                StreamBuilder<bool>(
                  stream: ConnectionService().connectionStatus,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && !snapshot.data!) {
                      return _buildConnectionBanner();
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          
          // Bottom Navigation (Mobile Only)
          bottomNavigationBar: isSmallScreen ? _buildBottomNavigation() : null,
        );
      },
    );
  }

  // Connection status banner
  Widget _buildConnectionBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 4,
        color: Colors.orange.shade700,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connection lost. Reconnecting...',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 280,
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
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Uriel Academy',
              style: AppStyles.brandNameStyle(
                fontSize: 20,
              ),
            ),
          ),
          
          // User Profile Card
          GestureDetector(
            onTap: () => setState(() {
              _showingProfile = !_showingProfile;
              if (_showingProfile) _selectedIndex = 0;
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1A1E3F).withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1A1E3F),
                    backgroundImage: _getAvatarImage(),
                    child: _getAvatarImage() == null ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        Text(
                          schoolName,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
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
                    ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(),
                  ),
                  
                  _buildNavItem(-1, 'Pricing'),
                  _buildNavItem(-2, 'About Us'),
                  _buildNavItem(-3, 'Contact'),
                  _buildNavItem(-4, 'Privacy Policy'),
                  _buildNavItem(-5, 'Terms of Service'),
                ],
              ),
            ),
          ),
          
          // Logout Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.grey[600]),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    final isSelected = index >= 0 && _selectedIndex == index && !_showingProfile;
    
    return InkWell(
      onTap: () {
        if (index >= 0) {
          setState(() {
            _selectedIndex = index;
            _showingProfile = false;
          });
        } else {
          _handleStaticPageNavigation(index);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1E3F).withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _showingProfile = !_showingProfile;
              if (_showingProfile) _selectedIndex = 0;
            }),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1A1E3F),
              backgroundImage: _getAvatarImage(),
              child: _getAvatarImage() == null ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  schoolName,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${userName.split(' ').first}',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schoolName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Profile button
          GestureDetector(
            onTap: () => setState(() {
              _showingProfile = !_showingProfile;
              if (_showingProfile) _selectedIndex = 0;
            }),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1A1E3F),
              backgroundImage: _getAvatarImage(),
              child: _getAvatarImage() == null ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final nav = _navItems();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: nav.take(5).map((item) {
              final index = item['index'] as int;
              final label = item['label'] as String;
              final isSelected = _selectedIndex == index && !_showingProfile;
              
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedIndex = index;
                    _showingProfile = false;
                  }),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIconForIndex(index),
                        color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: isSelected ? const Color(0xFF1A1E3F) : Colors.grey,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.people;
      case 2: return Icons.school;
      case 3: return Icons.person;
      case 4: return Icons.library_books;
      case 5: return Icons.quiz;
      case 6: return Icons.leaderboard;
      default: return Icons.dashboard;
    }
  }

  List<Widget> _homeChildren() {
    return [
      const SchoolAdminDashboard(),        // 0: Dashboard
      const SchoolAdminStudentsPage(),     // 1: Students
      const SchoolAdminTeachersPage(),     // 2: Teachers
      const UriPage(embedded: true),       // 3: Ask Uri
      _buildTextbooksPage(),               // 4: Books
      _buildTriviaPage(),                  // 5: Trivia
      const RedesignedLeaderboardPage(),   // 6: Leaderboard
      _buildFeedbackPage(),                // 7: Feedback
    ];
  }

  List<Map<String, Object?>> _navItems() {
    return [
      {'index': 0, 'label': 'Dashboard'},
      {'index': 1, 'label': 'Students'},
      {'index': 2, 'label': 'Teachers'},
      {'index': 3, 'label': 'Ask Uri'},
      {'index': 4, 'label': 'Books'},
      {'index': 5, 'label': 'Trivia'},
      {'index': 6, 'label': 'Leaderboard'},
      {'index': 7, 'label': 'Feedback'},
    ];
  }

  Widget _buildTextbooksPage() {
    return const TextbooksPage();
  }

  Widget _buildTriviaPage() {
    return const TriviaCategoriesPage();
  }

  Widget _buildFeedbackPage() {
    return const FeedbackPage();
  }

  void _handleStaticPageNavigation(int index) {
    // Handle navigation to static pages (Pricing, About, etc.)
    // These would typically open web views or new routes
    debugPrint('Navigate to static page: $index');
  }

  void _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1E3F),
            ),
            child: Text('Logout', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
