import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final int _pageSize = 20;
  int _currentPage = 1;
  final Set<String> _selectedUserIds = {};
  StreamSubscription<QuerySnapshot>? _usersStreamSubscription;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startRealTimeUserStream();
    _searchController.addListener(_filterUsers);
    // Auto-refresh every 2 minutes to update relative times
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI to update "time ago" displays
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    _usersStreamSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeUserStream() {
    setState(() => _isLoading = true);

    try {
      // Use real-time stream for live updates
      _usersStreamSubscription = _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;

        List<Map<String, dynamic>> usersList = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final userId = doc.id;

          // Debug: Log first user's data structure
          if (usersList.isEmpty) {
            debugPrint('📊 Sample user data structure:');
            debugPrint('  Available fields: ${data.keys.toList()}');
            debugPrint('  lastSeen: ${data['lastSeen']}');
            debugPrint('  lastActiveAt: ${data['lastActiveAt']}');
            debugPrint('  phone: ${data['phone']}');
            debugPrint('  phoneNumber: ${data['phoneNumber']}');
            debugPrint('  contactNumber: ${data['contactNumber']}');
            debugPrint('  parentEmail: ${data['parentEmail']}');
            debugPrint('  parentPhone: ${data['parentPhone']}');
            debugPrint('  parent object: ${data['parent']}');
          }

          // Get last seen - check multiple fields for compatibility
          final lastSeen =
              data['lastSeen'] ?? data['lastActiveAt'] ?? data['lastActive'];
          DateTime? lastSeenDate;
          if (lastSeen != null) {
            if (lastSeen is Timestamp) {
              lastSeenDate = lastSeen.toDate();
            } else if (lastSeen is String) {
              lastSeenDate = DateTime.tryParse(lastSeen);
            } else if (lastSeen is int) {
              lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
            }
          }

          // Get account created date
          final createdAt = data['createdAt'];
          DateTime? createdDate;
          if (createdAt != null) {
            if (createdAt is Timestamp) {
              createdDate = createdAt.toDate();
            } else if (createdAt is String) {
              createdDate = DateTime.tryParse(createdAt);
            } else if (createdAt is int) {
              createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
            }
          }

          // Get contact number - check multiple possible field names
          String contact = 'N/A';
          final possibleContactFields = [
            'phoneNumber',
            'phone',
            'contactNumber',
            'contact',
            'mobileNumber',
            'mobile'
          ];
          for (final field in possibleContactFields) {
            if (data[field] != null && data[field].toString().isNotEmpty) {
              contact = data[field].toString();
              break;
            }
          }

          // Get parent email - check multiple possible locations
          String parentEmail = 'N/A';
          if (data['parentEmail'] != null &&
              data['parentEmail'].toString().isNotEmpty) {
            parentEmail = data['parentEmail'].toString();
          } else if (data['parent'] is Map) {
            final parentData = data['parent'] as Map;
            if (parentData['email'] != null &&
                parentData['email'].toString().isNotEmpty) {
              parentEmail = parentData['email'].toString();
            }
          } else if (data['guardian'] is Map) {
            final guardianData = data['guardian'] as Map;
            if (guardianData['email'] != null &&
                guardianData['email'].toString().isNotEmpty) {
              parentEmail = guardianData['email'].toString();
            }
          }

          // Get parent contact - check multiple possible locations
          String parentContact = 'N/A';
          final possibleParentFields = [
            'parentPhone',
            'parentContact',
            'parentNumber',
            'guardianPhone',
            'guardianContact'
          ];

          for (final field in possibleParentFields) {
            if (data[field] != null && data[field].toString().isNotEmpty) {
              parentContact = data[field].toString();
              break;
            }
          }

          // Check nested parent object
          if (parentContact == 'N/A') {
            if (data['parent'] is Map) {
              final parentData = data['parent'] as Map;
              final parentPhoneFields = [
                'phone',
                'phoneNumber',
                'contact',
                'mobile'
              ];
              for (final field in parentPhoneFields) {
                if (parentData[field] != null &&
                    parentData[field].toString().isNotEmpty) {
                  parentContact = parentData[field].toString();
                  break;
                }
              }
            } else if (data['guardian'] is Map) {
              final guardianData = data['guardian'] as Map;
              final guardianPhoneFields = [
                'phone',
                'phoneNumber',
                'contact',
                'mobile'
              ];
              for (final field in guardianPhoneFields) {
                if (guardianData[field] != null &&
                    guardianData[field].toString().isNotEmpty) {
                  parentContact = guardianData[field].toString();
                  break;
                }
              }
            }
          }

          usersList.add({
            'userId': userId,
            'name': data['displayName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            'email': data['email'] ?? '',
            'contact': contact,
            'school': data['school'] ?? 'N/A',
            'class': data['class'] ?? data['grade'] ?? 'N/A',
            'role': data['role'] ?? 'student',
            'xp': (data['totalXP'] ?? data['xp'] ?? 0) as num,
            'lastSeen': lastSeenDate,
            'createdAt': createdDate,
            'avatar': data['avatar'],
            'parentEmail': parentEmail,
            'parentContact': parentContact,
          });
        }

        setState(() {
          _users = usersList;
          _filteredUsers = usersList;
          _isLoading = false;
        });
        _filterUsers(); // Apply any active search filter
      }, onError: (error) {
        debugPrint('Error in user stream: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      debugPrint('Error starting user stream: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final contact = (user['contact'] ?? '').toString().toLowerCase();
          final school = (user['school'] ?? '').toString().toLowerCase();
          final className = (user['class'] ?? '').toString().toLowerCase();
          final role = (user['role'] ?? '').toString().toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              contact.contains(query) ||
              school.contains(query) ||
              className.contains(query) ||
              role.contains(query);
        }).toList();
      }
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get _paginatedUsers {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex >= _filteredUsers.length) return [];
    if (endIndex >= _filteredUsers.length) {
      return _filteredUsers.sublist(startIndex);
    }
    return _filteredUsers.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    return (_filteredUsers.length / _pageSize)
        .ceil()
        .clamp(1, double.infinity)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;
    final paginatedUsers = _paginatedUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all users across the platform',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search and Actions Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                              hintText:
                                  'Search by name, email, contact, school, class, or role...',
                              hintStyle: GoogleFonts.montserrat(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey[500], size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatChip(
                                'Total Users',
                                _users.length.toString(),
                                const Color(0xFF007AFF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatChip(
                                'Filtered',
                                _filteredUsers.length.toString(),
                                const Color(0xFF34C759),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatChip(
                                'Selected',
                                _selectedUserIds.length.toString(),
                                const Color(0xFFFF9500),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons
                        if (_selectedUserIds.isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showSendMessageDialog,
                                  icon: const Icon(Icons.send, size: 18),
                                  label: Text(
                                    'Send Message (${_selectedUserIds.length})',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007AFF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _deleteSelectedUsers,
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: Text(
                                    'Delete (${_selectedUserIds.length})',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3B30),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User Table
          if (_isLoading && _users.isEmpty)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF007AFF))),
            )
          else if (_filteredUsers.isEmpty)
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
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search query',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: isSmallScreen
                    ? _buildMobileUserCards(paginatedUsers)
                    : _buildDesktopUserTable(paginatedUsers),
              ),
            ),

          // Pagination Controls
          if (_filteredUsers.isNotEmpty)
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
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          color: _currentPage > 1
                              ? const Color(0xFF007AFF)
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _currentPage < _totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          color: _currentPage < _totalPages
                              ? const Color(0xFF007AFF)
                              : Colors.grey[400],
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

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUserCards(List<Map<String, dynamic>> users) {
    return Column(
      children: users.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        final userNumber = (_currentPage - 1) * _pageSize + index + 1;
        return _buildUserCard(user, userNumber);
      }).toList(),
    );
  }

  Widget _buildDesktopUserTable(List<Map<String, dynamic>> users) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: _selectedUserIds.length == _filteredUsers.length &&
                        _filteredUsers.isNotEmpty,
                    onChanged: (val) => _toggleSelectAll(),
                    activeColor: const Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(width: 12),
                // Number
                SizedBox(
                  width: 50,
                  child: Text(
                    '#',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Name & Email (stacked)
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name / Email',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Contact
                Expanded(
                  flex: 2,
                  child: Text(
                    'Contact',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // School & Class (stacked)
                Expanded(
                  flex: 3,
                  child: Text(
                    'School / Class',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Role / XP (stacked)
                Expanded(
                  flex: 2,
                  child: Text(
                    'Role / XP',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Parent Info (stacked)
                Expanded(
                  flex: 3,
                  child: Text(
                    'Parent Email / Contact',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                // Created & Last Seen (stacked)
                Expanded(
                  flex: 2,
                  child: Text(
                    'Created / Last Seen',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          ...users.asMap().entries.map((entry) {
            final index = entry.key;
            final user = entry.value;
            final userNumber = (_currentPage - 1) * _pageSize + index + 1;
            return _buildUserRow(user, userNumber);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user, int userNumber) {
    final userId = user['userId'] ?? '';
    final isSelected = _selectedUserIds.contains(userId);
    final name = user['name'] ?? 'No Name';
    final email = user['email'] ?? 'N/A';
    final contact = user['contact'] ?? 'N/A';
    final school = user['school'] ?? 'N/A';
    final className = user['class'] ?? 'N/A';
    final role = user['role'] ?? 'student';
    final lastSeen = user['lastSeen'];
    final createdAt = user['createdAt'];
    final parentEmail = user['parentEmail'] ?? 'N/A';
    final parentContact = user['parentContact'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) => _toggleUserSelection(userId),
              activeColor: const Color(0xFF007AFF),
            ),
          ),
          const SizedBox(width: 12),
          // Number
          SizedBox(
            width: 50,
            child: Text(
              '$userNumber',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          // Name & Email (stacked)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _getRoleColor(role).withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(role),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contact
          Expanded(
            flex: 2,
            child: Text(
              contact,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // School & Class (stacked)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  school,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  className,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Role & XP (stacked)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getRoleLabel(role),
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getRoleColor(role),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatNumber(user['xp'])} XP',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Parent Info (stacked)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parentEmail,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  parentContact,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Created & Last Seen (stacked)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatLastSeen(lastSeen),
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int userNumber) {
    final userId = user['userId'] ?? '';
    final isSelected = _selectedUserIds.contains(userId);
    final name = user['name'] ?? 'No Name';
    final email = user['email'] ?? 'N/A';
    final contact = user['contact'] ?? 'N/A';
    final school = user['school'] ?? 'N/A';
    final className = user['class'] ?? 'N/A';
    final role = user['role'] ?? 'student';
    final lastSeen = user['lastSeen'];
    final createdAt = user['createdAt'];
    final parentEmail = user['parentEmail'] ?? 'N/A';
    final parentContact = user['parentContact'] ?? 'N/A';

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
          onTap: () => _toggleUserSelection(userId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (val) => _toggleUserSelection(userId),
                      activeColor: const Color(0xFF007AFF),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          _getRoleColor(role).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getRoleColor(role),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            email,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildRoleBadge(role),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[200], height: 1),
                const SizedBox(height: 12),
                _buildInfoRow('Contact', contact),
                const SizedBox(height: 6),
                _buildInfoRow('School', school),
                const SizedBox(height: 6),
                _buildInfoRow('Class', className),
                const SizedBox(height: 6),
                _buildInfoRow('Parent Email', parentEmail),
                const SizedBox(height: 6),
                _buildInfoRow('Parent Contact', parentContact),
                const SizedBox(height: 6),
                _buildInfoRow('Created', _formatDate(createdAt)),
                const SizedBox(height: 6),
                _buildInfoRow('Last Seen', _formatLastSeen(lastSeen)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedUserIds.length == _filteredUsers.length) {
        _selectedUserIds.clear();
      } else {
        _selectedUserIds.clear();
        _selectedUserIds
            .addAll(_filteredUsers.map((u) => u['userId'] as String));
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'Never';

    try {
      DateTime? dateTime;

      if (lastSeen is Timestamp) {
        dateTime = lastSeen.toDate();
      } else if (lastSeen is String) {
        dateTime = DateTime.tryParse(lastSeen);
      }

      if (dateTime == null) return 'Never';

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30)
        return '${(difference.inDays / 7).floor()}w ago';
      if (difference.inDays < 365)
        return '${(difference.inDays / 30).floor()}mo ago';
      return '${(difference.inDays / 365).floor()}y ago';
    } catch (e) {
      return 'Never';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    try {
      DateTime? dateTime;

      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.tryParse(date);
      } else if (date is DateTime) {
        dateTime = date;
      }

      if (dateTime == null) return 'N/A';

      // Format as: Dec 6, 2024
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _showSendMessageDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.send, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Send Message',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sending to ${_selectedUserIds.length} user(s)',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Field
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.montserrat(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: GoogleFonts.montserrat(),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Message Field
                    TextField(
                      controller: messageController,
                      style: GoogleFonts.montserrat(fontSize: 15),
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: GoogleFonts.montserrat(),
                        filled: true,
                        fillColor: const Color(0xFFF5F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty ||
                            messageController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please fill in all fields',
                                style: GoogleFonts.montserrat(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context);

                        try {
                          final callable =
                              _functions.httpsCallable('sendMessage');
                          await callable.call({
                            'recipientType': 'multiple',
                            'recipientIds': _selectedUserIds.toList(),
                            'title': titleController.text.trim(),
                            'message': messageController.text.trim(),
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Message sent successfully!',
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: const Color(0xFF34C759),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error sending message: $e',
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 18),
                      label: Text(
                        'Send Message',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedUsers() async {
    final count = _selectedUserIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Users',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete $count user(s)? This action cannot be undone.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: const Color(0xFF007AFF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'uids': _selectedUserIds.toList()});

      setState(() {
        _users.removeWhere((user) => _selectedUserIds.contains(user['userId']));
        _filteredUsers
            .removeWhere((user) => _selectedUserIds.contains(user['userId']));
        _selectedUserIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count user(s) deleted successfully',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: const Color(0xFF34C759),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildRoleBadge(String role) {
    final color = _getRoleColor(role);
    final label = _getRoleLabel(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'student':
        return 'Student';
      case 'teacher':
        return 'Teacher';
      case 'school_admin':
        return 'Admin';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role;
    }
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final num value = number is num ? number : 0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toInt().toString();
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
}
