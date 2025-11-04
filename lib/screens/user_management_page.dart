import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  String _selectedRole = 'all'; // all, student, teacher, school_admin
  List<DocumentSnapshot> _users = [];
  bool _isLoading = false;
  final int _pageSize = 20;
  int _currentPage = 1;
  int _totalPages = 1;
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _currentPage = 1;
    _loadUsers(isRefresh: true);
  }

  Future<void> _loadUsers({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _users.clear();
        _selectedUserIds.clear();
      }
    });

    try {
      // Fetch all users without index requirement
      Query query = _firestore.collection('users');
      
      // Only order by createdAt to avoid index requirement
      query = query.orderBy('createdAt', descending: true);

      final snapshot = await query.get();

      setState(() {
        _users = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _onRoleFilterChanged(String role) {
    if (_selectedRole == role) return;
    setState(() {
      _selectedRole = role;
      _currentPage = 1;
    });
  }

  List<DocumentSnapshot> get _filteredUsers {
    final query = _searchController.text.toLowerCase().trim();
    
    // Filter by role first
    List<DocumentSnapshot> filtered = _users.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      
      // Apply role filter
      if (_selectedRole != 'all') {
        final role = data['role'] ?? '';
        if (role != _selectedRole) return false;
      }
      
      // Apply search filter
      if (query.isNotEmpty) {
        final email = (data['email'] ?? '').toString().toLowerCase();
        final displayName = (data['displayName'] ?? '').toString().toLowerCase();
        final firstName = (data['firstName'] ?? '').toString().toLowerCase();
        final lastName = (data['lastName'] ?? '').toString().toLowerCase();
        
        return email.contains(query) || 
               displayName.contains(query) ||
               firstName.contains(query) ||
               lastName.contains(query);
      }
      
      return true;
    }).toList();
    
    // Calculate total pages
    _totalPages = (filtered.length / _pageSize).ceil();
    if (_totalPages == 0) _totalPages = 1;
    
    // Return paginated results
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;
    
    if (startIndex >= filtered.length) return [];
    if (endIndex >= filtered.length) return filtered.sublist(startIndex);
    
    return filtered.sublist(startIndex, endIndex);
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;
    final startNumber = (_currentPage - 1) * _pageSize + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Apple's light gray background
      body: CustomScrollView(
        slivers: [
          // Search Card Header
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.montserrat(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: GoogleFonts.montserrat(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Role Filter Chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildRoleChip('All Users', 'all'),
                      _buildRoleChip('Students', 'student'),
                      _buildRoleChip('Teachers', 'teacher'),
                      _buildRoleChip('School Admins', 'school_admin'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // User List
          if (_isLoading && _users.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF007AFF))),
            )
          else if (filteredUsers.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = filteredUsers[index];
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return const SizedBox.shrink();

                    final userNumber = startNumber + index;
                    return _buildUserCard(doc.id, data, userNumber);
                  },
                  childCount: filteredUsers.length,
                ),
              ),
            ),
          
          // Pagination Controls
          if (filteredUsers.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $_currentPage of $_totalPages',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _currentPage > 1 ? _previousPage : null,
                          icon: const Icon(Icons.chevron_left),
                          color: _currentPage > 1 ? const Color(0xFF007AFF) : Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _currentPage < _totalPages ? _nextPage : null,
                          icon: const Icon(Icons.chevron_right),
                          color: _currentPage < _totalPages ? const Color(0xFF007AFF) : Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, String role) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => _onRoleFilterChanged(role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data, int userNumber) {
    final email = data['email'] ?? 'N/A';
    final firstName = data['firstName'] ?? data['profile']?['firstName'] ?? '';
    final lastName = data['lastName'] ?? data['profile']?['lastName'] ?? '';
    final displayName = data['displayName'] ?? '$firstName $lastName'.trim();
    final role = data['role'] ?? 'student';
    final xp = data['totalXP'] ?? data['xp'] ?? data['badges']?['points'] ?? 0;
    final isSelected = _selectedUserIds.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(userId);
              } else {
                _selectedUserIds.add(userId);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$userNumber',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (displayName.isNotEmpty ? displayName[0] : email[0]).toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(role),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isEmpty ? 'No Name' : displayName,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildBadge(_getRoleLabel(role), _getRoleColor(role)),
                          const SizedBox(width: 8),
                          _buildBadge('$xp XP', Colors.grey[700]!),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Actions
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showUserActions(userId, email),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  void _showUserActions(String userId, String email) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              'Delete User',
              Icons.delete_outline,
              Colors.red,
              () {
                Navigator.pop(context);
                _deleteUser(userId, email);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete $email?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.montserrat(color: const Color(0xFF007AFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'uids': [userId]});

      setState(() {
        _users.removeWhere((doc) => doc.id == userId);
        _selectedUserIds.remove(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User deleted successfully', style: GoogleFonts.montserrat()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.montserrat()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'student':
        return const Color(0xFF007AFF);
      case 'teacher':
        return const Color(0xFF34C759);
      case 'school_admin':
        return const Color(0xFFFF9500);
      case 'super_admin':
        return const Color(0xFFAF52DE);
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'student':
        return 'Student';
      case 'teacher':
        return 'Teacher';
      case 'school_admin':
        return 'School Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role;
    }
  }
}

// All Users Tab
