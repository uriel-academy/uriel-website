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

  // Notifications state
  int _unreadNotificationCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

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
    _loadNotifications();
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
    _notificationsSubscription?.cancel();
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
          // Profile button with notification badge
          GestureDetector(
            onTap: () => _showProfileMenu(),
            child: Stack(
              clipBehavior: Clip.none,
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
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  void _loadNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _notificationsSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _notifications = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList();
            
            _unreadNotificationCount = _notifications.where((n) => n['read'] == false).length;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _showProfileMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        final dialogWidth = 320.0;
        
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: 70,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: dialogWidth,
                  constraints: const BoxConstraints(maxHeight: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF1A1E3F),
                              backgroundImage: _getAvatarImage(),
                              child: _getAvatarImage() == null ? Text(
                                userName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    schoolName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _buildProfileMenuItem(Icons.person, 'Profile Settings', () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedIndex = 0;
                          _showingProfile = true;
                        });
                      }),
                      
                      const Divider(height: 1),
                      
                      _buildProfileMenuItem(
                        Icons.notifications_outlined,
                        'Notifications',
                        () {
                          Navigator.pop(context);
                          _showNotificationsDialog();
                        },
                        badge: _unreadNotificationCount > 0 ? _unreadNotificationCount : null,
                      ),
                      
                      const Divider(height: 1),
                      
                      _buildProfileMenuItem(
                        Icons.logout,
                        'Sign Out',
                        _handleSignOut,
                        color: const Color(0xFFD62828),
                      ),
                      
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileMenuItem(IconData icon, String title, VoidCallback onTap, {Color? color, int? badge}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: color ?? Colors.grey[700]),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: color ?? Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    // Use the same notification dialog implementation from home_page.dart
    // Copy the exact implementation here
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: 70,
              right: 16,
              child: Material(
                elevation: 16,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 420,
                  constraints: const BoxConstraints(maxHeight: 600),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF001F3F),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Notifications', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                                  if (_unreadNotificationCount > 0)
                                    Text('$_unreadNotificationCount unread', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                                ],
                              ),
                            ),
                            if (_unreadNotificationCount > 0)
                              TextButton(
                                onPressed: () => _markAllAsRead(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: _notifications.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(48),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Text('No notifications yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                    const SizedBox(height: 8),
                                    Text('Messages from teachers and system will appear here', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500])),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(8),
                                itemCount: _notifications.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) => _buildNotificationItem(_notifications[index]),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final isRead = notification['read'] ?? false;
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final senderName = notification['senderName'] ?? 'System';
    final senderRole = notification['senderRole'] ?? 'app';
    final timestamp = notification['timestamp'] as Timestamp?;
    
    IconData senderIcon;
    Color senderColor;
    String senderLabel;
    
    if (senderRole == 'super_admin' || senderRole == 'app') {
      senderIcon = Icons.school_rounded;
      senderColor = const Color(0xFF007AFF);
      senderLabel = 'Uriel Academy';
    } else if (senderRole == 'school_admin') {
      senderIcon = Icons.admin_panel_settings_rounded;
      senderColor = const Color(0xFFFF9500);
      senderLabel = 'School Admin';
    } else if (senderRole == 'teacher') {
      senderIcon = Icons.person_rounded;
      senderColor = const Color(0xFF34C759);
      senderLabel = 'Teacher';
    } else {
      senderIcon = Icons.info_rounded;
      senderColor = Colors.grey;
      senderLabel = 'System';
    }
    
    return InkWell(
      onTap: () => _markNotificationAsRead(notification['id']),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.transparent : const Color(0xFF007AFF).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: senderColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(senderIcon, size: 20, color: senderColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A1E3F)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: senderColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(senderIcon, size: 12, color: senderColor),
                            const SizedBox(width: 4),
                            Text(senderLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: senderColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatTimestamp(timestamp), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final notification in _notifications) {
        if (notification['read'] == false) {
          batch.update(
            FirebaseFirestore.instance.collection('notifications').doc(notification['id']),
            {'read': true},
          );
        }
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  void _handleSignOut() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
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
