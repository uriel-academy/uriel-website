import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/rme_data_import_service.dart';
import '../utils/web_compatibility.dart';
import 'admin_question_management.dart';
import 'user_management_page.dart';
import 'content_management_page.dart';
import 'trivia_management_page.dart';

class ComprehensiveAdminDashboard extends StatefulWidget {
  const ComprehensiveAdminDashboard({super.key});

  @override
  State<ComprehensiveAdminDashboard> createState() => _ComprehensiveAdminDashboardState();
}

class _ComprehensiveAdminDashboardState extends State<ComprehensiveAdminDashboard> {
  bool _isAuthorized = false;
  bool _isLoading = true;
  
  bool isSidebarCollapsed = false;
  String selectedModule = 'overview';
  String adminRole = 'Super Admin'; // This would come from UserService
  String adminName = 'Admin User'; // This would come from UserService
  bool showNotifications = false;
  bool showQuickActions = false;
  bool showProfileMenu = false;
  final TextEditingController searchController = TextEditingController();

  // Mock data for dashboard metrics
  final Map<String, dynamic> dashboardMetrics = {
    'activeStudents': {'count': 2847, 'growth': 12.5, 'trend': 'up'},
    'schoolsOnboarded': {'count': 156, 'growth': 8.2, 'trend': 'up'},
    'revenueThisMonth': {'amount': 28450.75, 'growth': -3.1, 'trend': 'down'},
    'flaggedAccounts': {'count': 23, 'critical': 5, 'normal': 18},
    'totalSubscriptions': {'active': 2654, 'expired': 193, 'renewalRate': 87.3},
    'contentLibrary': {'questions': 15420, 'textbooks': 342, 'newUploads': 47},
    'parentEngagement': {'reportsSent': 1258, 'openRate': 68.4},
    'systemUptime': {'percentage': 99.8, 'lastIncident': '3 days ago'},
  };

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
          
          // If not authorized, redirect to login
          if (!_isAuthorized && !_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showUnauthorizedDialog();
            });
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
  
  void _showUnauthorizedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.security,
                color: Color(0xFFD62828),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Access Denied',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin access is restricted to authorized personnel only.',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please sign in with an authorized admin account.',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text(
                'Sign In',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/landing');
              },
              child: Text(
                'Go Home',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
    
    // If authorized, show the comprehensive admin dashboard
    final isSmallScreen = MediaQuery.of(context).size.width < 768;
    final isMobileScreen = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Row(
            children: [
              // Left Sidebar - Always present for desktop, hidden for mobile when collapsed
              if (!isMobileScreen)
                _buildSidebar(isSmallScreen, isMobileScreen),
              
              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Top Header Bar
                    _buildTopHeader(context, isSmallScreen, isMobileScreen),
                    
                    // Main Dashboard Content
                    Expanded(
                      child: _buildMainContent(isSmallScreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Mobile sidebar overlay
          if (isMobileScreen && !isSidebarCollapsed)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Row(
                  children: [
                    _buildSidebar(isSmallScreen, isMobileScreen),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isSidebarCollapsed = true;
                          });
                        },
                        child: Container(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Add floating action button for mobile menu
      floatingActionButton: isMobileScreen ? GestureDetector(
        onLongPress: () {
          // Show import options
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Quick Import',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.upload_file, color: Color(0xFFFF9800)),
                    title: Text('Import RME Questions'),
                    subtitle: Text('1999 BECE - 40 questions'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _importRMEData();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings, color: Color(0xFF2196F3)),
                    title: Text('Set Admin Role'),
                    subtitle: Text('Grant admin access to users'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showSetAdminRoleDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF1A1E3F),
          elevation: 8,
          onPressed: () {
            setState(() {
              isSidebarCollapsed = !isSidebarCollapsed;
            });
          },
          child: Icon(
            isSidebarCollapsed ? Icons.menu : Icons.close,
            color: Colors.white,
          ),
        ),
      ) : PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'import_rme') {
            _importRMEData();
          } else if (value == 'set_admin') {
            _showSetAdminRoleDialog();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'import_rme',
            child: Row(
              children: [
                Icon(Icons.upload_file, color: Color(0xFFFF9800)),
                SizedBox(width: 8),
                Text('Import RME Questions'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'set_admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Color(0xFF2196F3)),
                SizedBox(width: 8),
                Text('Set Admin Role'),
              ],
            ),
          ),
        ],
        child: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFFF9800),
          elevation: 8,
          onPressed: null, // Handled by PopupMenuButton
          icon: Icon(Icons.admin_panel_settings, color: Colors.white),
          label: Text(
            'Admin Tools',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSidebar(bool isSmallScreen, [bool isMobileScreen = false]) {
    final sidebarWidth = isMobileScreen 
        ? (isSidebarCollapsed ? 0.0 : 280.0)
        : (isSidebarCollapsed ? 70.0 : 280.0);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1E3F),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (!isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Uriel Academy',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ADMIN PANEL',
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  onPressed: () {
                    setState(() {
                      isSidebarCollapsed = !isSidebarCollapsed;
                    });
                  },
                  icon: Icon(
                    isSidebarCollapsed ? Icons.menu_open : Icons.menu,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(Icons.dashboard, 'Home', 'overview'),
                _buildNavSection('USER MANAGEMENT'),
                _buildNavItem(Icons.people, 'Students', 'students'),
                _buildNavItem(Icons.family_restroom, 'Parents', 'parents'),
                _buildNavItem(Icons.school, 'Teachers', 'teachers'),
                _buildNavItem(Icons.account_balance, 'School Admins', 'school_admins'),
                
                _buildNavSection('CONTENT'),
                _buildNavItem(Icons.quiz, 'Past Questions', 'questions'),
                _buildNavItem(Icons.psychology, 'Trivia', 'trivia'),
                _buildNavItem(Icons.library_books, 'Textbooks', 'textbooks'),
                _buildNavItem(Icons.smart_toy, 'AI Tools Config', 'ai_tools'),
                _buildNavItem(Icons.perm_media, 'Multimedia', 'multimedia'),
                
                _buildNavSection('PLATFORM'),
                _buildNavItem(Icons.business, 'Institutions', 'institutions'),
                _buildNavItem(Icons.payments, 'Finance', 'finance'),
                _buildNavItem(Icons.analytics, 'Reports', 'reports'),
                _buildNavItem(Icons.message, 'Communications', 'communications'),
                _buildNavItem(Icons.emoji_events, 'Gamification', 'gamification'),
                
                _buildNavSection('SYSTEM'),
                _buildNavItem(Icons.security, 'Security', 'security'),
                _buildNavItem(Icons.settings, 'Settings', 'settings'),
              ],
            ),
          ),
          
          // Sidebar Footer
          if (!isSidebarCollapsed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2ECC71),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'System Online',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      adminRole,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildNavSection(String title) {
    if (isSidebarCollapsed) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, String moduleKey) {
    final isSelected = selectedModule == moduleKey;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _handleNavigation(moduleKey);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD62828).withOpacity(0.15) : null,
              borderRadius: BorderRadius.circular(8),
              border: isSelected 
                ? Border.all(color: const Color(0xFFD62828).withOpacity(0.3))
                : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFFD62828) : Colors.white70,
                  size: 20,
                ),
                if (!isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFD62828) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String moduleKey) {
    setState(() {
      selectedModule = moduleKey;
    });

    // Navigate to appropriate pages
    switch (moduleKey) {
      case 'students':
      case 'teachers':
      case 'school_admins':
      case 'parents':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserManagementPage(),
          ),
        );
        break;
      case 'questions':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminQuestionManagementPage(),
          ),
        );
        break;
      case 'trivia':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TriviaManagementPage(),
          ),
        );
        break;
      case 'textbooks':
      case 'multimedia':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ContentManagementPage(),
          ),
        );
        break;
      case 'overview':
        // Stay on current dashboard
        break;
      default:
        // Show coming soon dialog for unimplemented features
        _showComingSoonDialog(moduleKey);
        break;
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Coming Soon',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'The $feature feature is currently under development.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, bool isSmallScreen, [bool isMobileScreen = false]) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobileScreen ? 12 : 24, 
          vertical: 12
        ),
        child: Row(
          children: [
            // Mobile menu button for top bar (backup to floating button)
            if (isMobileScreen) ...[
              IconButton(
                onPressed: () {
                  setState(() {
                    isSidebarCollapsed = !isSidebarCollapsed;
                  });
                },
                icon: Icon(
                  isSidebarCollapsed ? Icons.menu : Icons.close,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Global Search Bar
            Expanded(
              flex: isMobileScreen ? 4 : 3,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: isMobileScreen 
                        ? 'Search...' 
                        : 'Search students, schools, teachers, transactions...',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: isMobileScreen ? 12 : 14,
                      color: Colors.grey[500],
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: !isMobileScreen ? IconButton(
                      onPressed: () {
                        // TODO: Show advanced search filters
                      },
                      icon: const Icon(Icons.tune, color: Colors.grey),
                    ) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: isMobileScreen ? 8 : 24),
            
            // Notifications
            _buildHeaderAction(
              icon: Icons.notifications_outlined,
              badge: '12',
              onTap: () {
                setState(() {
                  showNotifications = !showNotifications;
                  showQuickActions = false;
                  showProfileMenu = false;
                });
              },
            ),
            
            const SizedBox(width: 16),
            
            // Quick Actions
            _buildHeaderAction(
              icon: Icons.flash_on_outlined,
              onTap: () {
                setState(() {
                  showQuickActions = !showQuickActions;
                  showNotifications = false;
                  showProfileMenu = false;
                });
              },
            ),
            
            const SizedBox(width: 24),
            
            // Admin Profile
            GestureDetector(
              onTap: () {
                setState(() {
                  showProfileMenu = !showProfileMenu;
                  showNotifications = false;
                  showQuickActions = false;
                });
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1A1E3F),
                    child: Text(
                      adminName[0],
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isSmallScreen) Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        adminName,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD62828).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          adminRole,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD62828),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Stack(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: const Color(0xFF1A1E3F), size: 22),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFD62828),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                badge,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent(bool isSmallScreen) {
    final isMobileScreen = MediaQuery.of(context).size.width < 600;
    
    return Padding(
      padding: EdgeInsets.all(isMobileScreen ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(isMobileScreen),
          
          SizedBox(height: isMobileScreen ? 16 : 24),
          
          // Main Dashboard Content
          Expanded(
            child: selectedModule == 'overview' 
              ? _buildOverviewDashboard(isSmallScreen)
              : _buildModuleContent(selectedModule, isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection([bool isMobileScreen = false]) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMobileScreen 
                    ? 'Welcome, $adminName'
                    : 'Welcome back, $adminName',
                style: GoogleFonts.montserrat(
                  fontSize: isMobileScreen ? 20 : 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      adminRole,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD62828),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Last login: Today at 9:24 AM',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'System Health: Excellent',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewDashboard(bool isSmallScreen) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Metrics Cards
          _buildTopMetricsGrid(isSmallScreen),
          
          const SizedBox(height: 32),
          
          // Secondary Metrics
          _buildSecondaryMetrics(isSmallScreen),
          
          const SizedBox(height: 32),
          
          // Analytics Section
          _buildAnalyticsSection(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildTopMetricsGrid(bool isSmallScreen) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isSmallScreen ? 1.5 : 1.8,
      children: [
        _buildMetricCard(
          title: 'Total Active Students',
          value: '${dashboardMetrics['activeStudents']['count']}',
          subtitle: 'New today: +47',
          growth: dashboardMetrics['activeStudents']['growth'],
          trend: dashboardMetrics['activeStudents']['trend'],
          icon: Icons.people,
          color: const Color(0xFF2ECC71),
        ),
        _buildMetricCard(
          title: 'Schools Onboarded',
          value: '${dashboardMetrics['schoolsOnboarded']['count']}',
          subtitle: 'New this month: +13',
          growth: dashboardMetrics['schoolsOnboarded']['growth'],
          trend: dashboardMetrics['schoolsOnboarded']['trend'],
          icon: Icons.school,
          color: const Color(0xFF3498DB),
        ),
        _buildMetricCard(
          title: 'Revenue This Month',
          value: 'GH₵${(dashboardMetrics['revenueThisMonth']['amount'] as double).toStringAsFixed(0)}',
          subtitle: 'vs last month',
          growth: dashboardMetrics['revenueThisMonth']['growth'],
          trend: dashboardMetrics['revenueThisMonth']['trend'],
          icon: Icons.trending_up,
          color: dashboardMetrics['revenueThisMonth']['trend'] == 'up' 
            ? const Color(0xFF2ECC71) 
            : const Color(0xFFD62828),
        ),
        _buildMetricCard(
          title: 'Flagged Accounts',
          value: '${dashboardMetrics['flaggedAccounts']['count']}',
          subtitle: 'Critical: ${dashboardMetrics['flaggedAccounts']['critical']}',
          growth: null,
          trend: null,
          icon: Icons.warning,
          color: const Color(0xFFD62828),
          actionText: 'Review Now',
          onAction: () {
            setState(() {
              selectedModule = 'security';
            });
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? growth,
    String? trend,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend == 'up' 
                      ? const Color(0xFF2ECC71).withOpacity(0.1)
                      : const Color(0xFFD62828).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend == 'up' ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: trend == 'up' 
                          ? const Color(0xFF2ECC71)
                          : const Color(0xFFD62828),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${growth.abs()}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trend == 'up' 
                            ? const Color(0xFF2ECC71)
                            : const Color(0xFFD62828),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              if (actionText != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionText,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryMetrics(bool isSmallScreen) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isSmallScreen ? 2.0 : 2.5,
      children: [
        _buildSmallMetricCard(
          'Total Subscriptions',
          '${dashboardMetrics['totalSubscriptions']['active']}',
          'Renewal rate: ${dashboardMetrics['totalSubscriptions']['renewalRate']}%',
          Icons.card_membership,
          const Color(0xFF9B59B6),
        ),
        _buildSmallMetricCard(
          'Content Library',
          '${dashboardMetrics['contentLibrary']['questions']}',
          'Questions available',
          Icons.quiz,
          const Color(0xFFE67E22),
        ),
        _buildSmallMetricCard(
          'Parent Engagement',
          '${dashboardMetrics['parentEngagement']['openRate']}%',
          'Report open rate',
          Icons.email,
          const Color(0xFF1ABC9C),
        ),
        _buildSmallMetricCard(
          'System Uptime',
          '${dashboardMetrics['systemUptime']['percentage']}%',
          'Last incident: ${dashboardMetrics['systemUptime']['lastIncident']}',
          Icons.cloud_done,
          const Color(0xFF2ECC71),
        ),
      ],
    );
  }

  Widget _buildSmallMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics Dashboard',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 16),
        
        if (isSmallScreen)
          Column(
            children: [
              _buildRevenueChart(),
              const SizedBox(height: 16),
              _buildUsageHeatmap(),
              const SizedBox(height: 16),
              _buildActivityFeed(),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildRevenueChart(),
                    const SizedBox(height: 16),
                    _buildUsageHeatmap(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildActivityFeed(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Revenue Trends',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Last 30 days',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 48,
                      color: const Color(0xFF2ECC71),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Revenue Analytics',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interactive revenue chart with subscription breakdown',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageHeatmap() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usage Heatmap',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Peak study times across Ghana',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.grid_view,
                      size: 40,
                      color: const Color(0xFF3498DB),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Activity Heatmap',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Days × Hours usage visualization',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    final activities = [
      {'type': 'signup', 'user': 'Kwame Asante', 'school': 'Achimota School', 'time': '2 min ago', 'plan': 'Monthly'},
      {'type': 'payment', 'amount': 'GH₵9.99', 'status': 'success', 'time': '5 min ago', 'user': 'Ama Boateng'},
      {'type': 'content', 'item': 'BECE Mathematics 2023', 'action': 'uploaded', 'time': '12 min ago', 'by': 'Content Team'},
      {'type': 'security', 'alert': 'Multiple login attempts', 'user': 'suspicious_user@email.com', 'time': '15 min ago'},
      {'type': 'report', 'recipient': 'Parent - Yaw Mensah', 'type_detail': 'Weekly Progress', 'time': '18 min ago'},
      {'type': 'signup', 'user': 'Akosua Frimpong', 'school': 'Wesley Girls School', 'time': '25 min ago', 'plan': 'Weekly'},
    ];

    return Container(
      height: 566,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live Activity Feed',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: activities.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityItem(activity);
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: Show full activity log
              },
              child: Text(
                'View All Activities',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, String> activity) {
    IconData icon;
    Color iconColor;
    String primaryText;
    String secondaryText;

    switch (activity['type']) {
      case 'signup':
        icon = Icons.person_add;
        iconColor = const Color(0xFF2ECC71);
        primaryText = '${activity['user']} signed up';
        secondaryText = '${activity['school']} • ${activity['plan']} Plan';
        break;
      case 'payment':
        icon = activity['status'] == 'success' ? Icons.payment : Icons.error;
        iconColor = activity['status'] == 'success' ? const Color(0xFF2ECC71) : const Color(0xFFD62828);
        primaryText = 'Payment ${activity['status']} • ${activity['amount']}';
        secondaryText = activity['user'] ?? '';
        break;
      case 'content':
        icon = Icons.upload_file;
        iconColor = const Color(0xFF3498DB);
        primaryText = '${activity['item']} ${activity['action']}';
        secondaryText = 'by ${activity['by']}';
        break;
      case 'security':
        icon = Icons.security;
        iconColor = const Color(0xFFD62828);
        primaryText = activity['alert'] ?? '';
        secondaryText = activity['user'] ?? '';
        break;
      case 'report':
        icon = Icons.report;
        iconColor = const Color(0xFF9B59B6);
        primaryText = '${activity['type_detail']} generated';
        secondaryText = 'for ${activity['recipient']}';
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
        primaryText = 'Unknown activity';
        secondaryText = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryText,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
                if (secondaryText.isNotEmpty)
                  Text(
                    secondaryText,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            activity['time'] ?? '',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleContent(String module, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getModuleIcon(module),
              size: 64,
              color: const Color(0xFF1A1E3F).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _getModuleTitle(module),
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This module is under development',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Coming Soon: Full ${_getModuleTitle(module)} Interface',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'students': return Icons.people;
      case 'parents': return Icons.family_restroom;
      case 'teachers': return Icons.school;
      case 'school_admins': return Icons.account_balance;
      case 'questions': return Icons.quiz;
      case 'textbooks': return Icons.library_books;
      case 'ai_tools': return Icons.smart_toy;
      case 'multimedia': return Icons.perm_media;
      case 'institutions': return Icons.business;
      case 'finance': return Icons.payments;
      case 'reports': return Icons.analytics;
      case 'communications': return Icons.message;
      case 'gamification': return Icons.emoji_events;
      case 'security': return Icons.security;
      case 'settings': return Icons.settings;
      default: return Icons.dashboard;
    }
  }

  String _getModuleTitle(String module) {
    switch (module) {
      case 'students': return 'Student Management';
      case 'parents': return 'Parent Management';
      case 'teachers': return 'Teacher Management';
      case 'school_admins': return 'School Admin Management';
      case 'questions': return 'Past Questions';
      case 'textbooks': return 'Textbook Library';
      case 'ai_tools': return 'AI Tools Configuration';
      case 'multimedia': return 'Multimedia Assets';
      case 'institutions': return 'Institution Management';
      case 'finance': return 'Finance Dashboard';
      case 'reports': return 'Reports & Analytics';
      case 'communications': return 'Communication Center';
      case 'gamification': return 'Gamification Control';
      case 'security': return 'Security & Monitoring';
      case 'settings': return 'System Settings';
      default: return 'Dashboard';
    }
  }

  // Import RME Data Method
  Future<void> _importRMEData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Import RME Data',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will import 40 RME questions from the 1999 BECE exam into the database. Continue?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
            ),
            child: Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Importing RME questions...',
                style: GoogleFonts.montserrat(),
              ),
            ],
          ),
        ),
      );

      try {
        final result = await RMEDataImportService.importRMEQuestions();
        
        Navigator.of(context).pop(); // Close loading dialog
        
        if (result['success'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Success'),
                ],
              ),
              content: Text(
                result['message'] ?? 'Successfully imported RME questions.',
                style: GoogleFonts.montserrat(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        } else {
          // Show error message from the result
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Error'),
                ],
              ),
              content: Text(
                result['message'] ?? 'Failed to import RME questions.',
                style: GoogleFonts.montserrat(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text(
              'Failed to import RME questions: $e',
              style: GoogleFonts.montserrat(),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Set Admin Role Method
  Future<void> _showSetAdminRoleDialog() async {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Set Admin Role',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the email address that should have admin access:',
                style: GoogleFonts.montserrat(),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'studywithuriel@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Note: This will grant super admin privileges. The user will need to sign out and sign in again to access admin features.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter an email address')),
                  );
                  return;
                }

                setState(() => isLoading = true);

                try {
                  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                  final callable = functions.httpsCallable('setAdminRole');
                  
                  final result = await callable.call({
                    'email': emailController.text.trim(),
                  });

                  Navigator.of(context).pop();
                  
                  // Safely handle the response data to avoid Int64 issues
                  final responseData = safeDocumentData(Map<String, dynamic>.from(result.data));
                  final message = responseData['message']?.toString() ?? 'Admin role set successfully!\n\nThe user should sign out and sign in again to access admin features.';
                  
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Success'),
                        ],
                      ),
                      content: Text(
                        message,
                        style: GoogleFonts.montserrat(),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );

                } catch (e) {
                  setState(() => isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text('Set Admin Role'),
            ),
          ],
        ),
      ),
    );
  }
}