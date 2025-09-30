import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'admin_question_management.dart';
import 'user_management_page.dart';
import 'content_management_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  bool _isAuthorized = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }
  
  Future<void> _checkAdminAccess() async {
    try {
      // Listen to auth state changes
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (mounted) {
          setState(() {
            _isAuthorized = user != null && user.email == 'studywithuriel@gmail.com';
            _isLoading = false;
          });
          
          // If not authorized, show unauthorized screen
          if (!_isAuthorized && !_isLoading) {
            // Screen will handle this in build method
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthorized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking authorization
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1E3F)),
              ),
              const SizedBox(height: 24),
              Text(
                'Verifying admin access...',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show access denied screen if not authorized
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.security,
                  color: Color(0xFFD62828),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Restricted',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This area is restricted to authorized admins only.',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/landing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1E3F),
                      side: const BorderSide(color: Color(0xFF1A1E3F)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Go Home',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
    
    // If authorized, show the admin dashboard
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
        centerTitle: false,
        actions: [
          // Mobile-responsive actions
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isNarrowScreen = screenWidth < 600;
              
              if (isNarrowScreen) {
                // Mobile: Show only logout button
                return IconButton(
                  onPressed: () async {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/landing');
                    }
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Sign Out',
                );
              } else {
                // Desktop: Show email and logout
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          FirebaseAuth.instance.currentUser?.email ?? '',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          await _authService.signOut();
                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/landing');
                          }
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Sign Out',
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MediaQuery.of(context).size.width < 600 
                ? Column(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFF1A1E3F),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Welcome to Admin Dashboard',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1E3F),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your platform with comprehensive controls',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF1A1E3F),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to Admin Dashboard',
                              style: GoogleFonts.montserrat(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1E3F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your platform with comprehensive controls',
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
            
            // Dashboard Access Section
            Text(
              'Dashboard Access',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            
            // Dashboard Navigation Cards
            Container(
              height: MediaQuery.of(context).size.width < 600 ? 100 : 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  _buildDashboardAccessCard(
                    'Student Dashboard',
                    'View student experience',
                    Icons.school,
                    const Color(0xFF3498DB),
                    () => Navigator.of(context).pushNamed('/dashboard'),
                  ),
                  _buildDashboardAccessCard(
                    'Teacher Dashboard',
                    'View teacher interface',
                    Icons.person_outline,
                    const Color(0xFF2ECC71),
                    () => Navigator.of(context).pushNamed('/teacher'),
                  ),
                  _buildDashboardAccessCard(
                    'School Dashboard',
                    'View school management',
                    Icons.business,
                    const Color(0xFFE67E22),
                    () => Navigator.of(context).pushNamed('/school'),
                  ),
                  _buildDashboardAccessCard(
                    'Parent Dashboard',
                    'View parent interface',
                    Icons.family_restroom,
                    const Color(0xFFE91E63),
                    () => Navigator.of(context).pushNamed('/parent'),
                  ),
                  _buildDashboardAccessCard(
                    'Comprehensive Admin',
                    'Full mission control',
                    Icons.dashboard,
                    const Color(0xFF8E44AD),
                    () => Navigator.of(context).pushReplacementNamed('/admin'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Admin Tools Grid
            Text(
              'Admin Tools',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.5 : 1.8,
                children: [
                  _buildAdminCard(
                    'Question Management',
                    'Add, import, and manage exam questions',
                    Icons.quiz,
                    const Color(0xFFD62828),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminQuestionManagementPage(),
                      ),
                    ),
                  ),
                  _buildAdminCard(
                    'User Management',
                    'Manage students, teachers, and parents',
                    Icons.people,
                    const Color(0xFF3498DB),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementPage(),
                      ),
                    ),
                  ),
                  _buildAdminCard(
                    'Content Control',
                    'Manage educational content and resources',
                    Icons.library_books,
                    const Color(0xFF2ECC71),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentManagementPage(),
                      ),
                    ),
                  ),
                  _buildAdminCard(
                    'Analytics',
                    'View platform insights and reports',
                    Icons.analytics,
                    const Color(0xFFE74C3C),
                    () => _showFeatureDialog('Analytics'),
                  ),
                  _buildAdminCard(
                    'System Settings',
                    'Configure platform settings',
                    Icons.settings,
                    const Color(0xFF9B59B6),
                    () => _showFeatureDialog('System Settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardAccessCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width < 600 ? 160 : 200,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
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
                    width: MediaQuery.of(context).size.width < 600 ? 28 : 32,
                    height: MediaQuery.of(context).size.width < 600 ? 28 : 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.width < 600 ? 8 : 12),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1E3F),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.montserrat(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 10 : 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeatureDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            feature,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          content: Text(
            'This feature is currently in development. The comprehensive admin dashboard with full functionality has been implemented in comprehensive_admin_dashboard.dart.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'User Profile',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1A1E3F),
              child: Text(
                FirebaseAuth.instance.currentUser?.email?.substring(0, 1).toUpperCase() ?? 'A',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              FirebaseAuth.instance.currentUser?.email ?? 'No email',
              style: GoogleFonts.montserrat(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Super Admin',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: const Color(0xFFD62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Settings',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeColor: const Color(0xFF1A1E3F),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: false,
                onChanged: (value) {},
                activeColor: const Color(0xFF1A1E3F),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              trailing: const Text('English'),
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/landing');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}