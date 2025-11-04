import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({Key? key}) : super(key: key);

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'User Management',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFD62828),
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'All Users'),
            Tab(icon: Icon(Icons.school), text: 'Students'),
            Tab(icon: Icon(Icons.person_outline), text: 'Teachers'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'School Admins'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AllUsersTab(searchController: _searchController),
          StudentManagementTab(searchController: _searchController),
          TeacherManagementTab(searchController: _searchController),
          SchoolAdminManagementTab(searchController: _searchController),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// All Users Tab
class AllUsersTab extends StatefulWidget {
  final TextEditingController searchController;
  const AllUsersTab({Key? key, required this.searchController}) : super(key: key);

  @override
  State<AllUsersTab> createState() => _AllUsersTabState();
}

class _AllUsersTabState extends State<AllUsersTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  List<DocumentSnapshot> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  int _pageSize = 20;
  final List<DocumentSnapshot> _pageStack = [];
  String _searchQuery = '';
  final Set<String> _selectedUserIds = {};
  
  @override
  void initState() {
    super.initState();
    _loadPageSize();
    _fetchUsers();
    widget.searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = widget.searchController.text.trim();
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
      _pageStack.clear();
      _selectedUserIds.clear();
    });
    _fetchUsers();
  }
  
  Future<void> _loadPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pageSize = prefs.getInt('userManagementPageSize') ?? 20;
    });
  }
  
  Future<void> _fetchUsers() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Query query = _firestore.collection('users');
      
      // Search by email or displayName
      if (_searchQuery.isNotEmpty) {
        if (_searchQuery.contains('@')) {
          query = query
              .where('email', isGreaterThanOrEqualTo: _searchQuery)
              .where('email', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        } else {
          query = query
              .where('displayName', isGreaterThanOrEqualTo: _searchQuery)
              .where('displayName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        }
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
      
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      
      final snapshot = await query.limit(_pageSize).get();
      
      setState(() {
        _users.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'userIds': [userId]});
      
      setState(() {
        _users.removeWhere((doc) => doc.id == userId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }
  
  Future<void> _sendMessageToUser(String userId, String email) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to $email', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': titleController.text,
        'message': messageController.text,
        'type': 'admin',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and actions bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by email or name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              if (_selectedUserIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${_selectedUserIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _bulkMessage,
                  icon: const Icon(Icons.message),
                  label: Text('Message (${_selectedUserIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Users table
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No users found',
                          style: GoogleFonts.montserrat(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selectedUserIds.length == _users.length && _users.isNotEmpty,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedUserIds.addAll(_users.map((doc) => doc.id));
                                      } else {
                                        _selectedUserIds.clear();
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('Email', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Date Created', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Last Login', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('XP', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Rank', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 100),
                              ],
                            ),
                          ),
                          // Table body
                          Expanded(
                            child: ListView.separated(
                              itemCount: _users.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = _users[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final userId = doc.id;
                                final email = data['email'] ?? 'N/A';
                                final createdAt = data['createdAt'] as Timestamp?;
                                final lastLogin = data['lastLogin'] as Timestamp?;
                                final xp = data['badges']?['points'] ?? 0;
                                final rankName = data['rankName'] ?? 'Beginner';
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: _selectedUserIds.contains(userId),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedUserIds.add(userId);
                                        } else {
                                          _selectedUserIds.remove(userId);
                                        }
                                      });
                                    },
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(email, style: GoogleFonts.montserrat()),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          createdAt != null
                                              ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                                              : 'N/A',
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          lastLogin != null
                                              ? '${lastLogin.toDate().day}/${lastLogin.toDate().month}/${lastLogin.toDate().year}'
                                              : 'N/A',
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text('$xp', style: GoogleFonts.montserrat()),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(rankName, style: GoogleFonts.montserrat()),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.message, size: 20),
                                            onPressed: () => _sendMessageToUser(userId, email),
                                            color: const Color(0xFF2ECC71),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
                                            onPressed: () => _deleteUser(userId, email),
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Pagination
                          if (_hasMore || _pageStack.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_pageStack.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _previousPage,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Previous'),
                                    ),
                                  if (_hasMore)
                                    TextButton.icon(
                                      onPressed: _fetchUsers,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Next'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
  
  void _previousPage() {
    if (_pageStack.isEmpty) return;
    setState(() {
      _lastDoc = _pageStack.removeLast();
      _users.clear();
      _hasMore = true;
    });
    _fetchUsers();
  }
  
  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateUserDialog(),
    );
  }
  
  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Users', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete ${_selectedUserIds.length} users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'userIds': _selectedUserIds.toList()});
      
      setState(() {
        _users.removeWhere((doc) => _selectedUserIds.contains(doc.id));
        _selectedUserIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Users deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting users: $e')),
        );
      }
    }
  }
  
  Future<void> _bulkMessage() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${_selectedUserIds.length} Users', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final batch = _firestore.batch();
      for (final userId in _selectedUserIds) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': userId,
          'title': titleController.text,
          'message': messageController.text,
          'type': 'admin',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      
      setState(() {
        _selectedUserIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending messages: $e')),
        );
      }
    }
  }
}

// Create User Dialog
class _CreateUserDialog extends StatefulWidget {
  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create User', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                    DropdownMenuItem(value: 'school_admin', child: Text('School Admin')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRole = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty || !val.contains('@') ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (val) => val!.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
  
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('adminCreateUser');
      await callable.call({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'role': _selectedRole,
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Students Tab
class StudentManagementTab extends StatefulWidget {
  final TextEditingController searchController;
  const StudentManagementTab({Key? key, required this.searchController}) : super(key: key);

  @override
  State<StudentManagementTab> createState() => _StudentManagementTabState();
}

class _StudentManagementTabState extends State<StudentManagementTab> {
  @override
  Widget build(BuildContext context) {
    return _RoleBasedUserTab(
      searchController: widget.searchController,
      role: 'student',
      roleLabel: 'Students',
    );
  }
}

// Teachers Tab
class TeacherManagementTab extends StatefulWidget {
  final TextEditingController searchController;
  const TeacherManagementTab({Key? key, required this.searchController}) : super(key: key);

  @override
  State<TeacherManagementTab> createState() => _TeacherManagementTabState();
}

class _TeacherManagementTabState extends State<TeacherManagementTab> {
  @override
  Widget build(BuildContext context) {
    return _RoleBasedUserTab(
      searchController: widget.searchController,
      role: 'teacher',
      roleLabel: 'Teachers',
    );
  }
}

// School Admins Tab
class SchoolAdminManagementTab extends StatefulWidget {
  final TextEditingController searchController;
  const SchoolAdminManagementTab({Key? key, required this.searchController}) : super(key: key);

  @override
  State<SchoolAdminManagementTab> createState() => _SchoolAdminManagementTabState();
}

class _SchoolAdminManagementTabState extends State<SchoolAdminManagementTab> {
  @override
  Widget build(BuildContext context) {
    return _RoleBasedUserTab(
      searchController: widget.searchController,
      role: 'school_admin',
      roleLabel: 'School Admins',
    );
  }
}

// Reusable Role-Based User Tab Widget
class _RoleBasedUserTab extends StatefulWidget {
  final TextEditingController searchController;
  final String role;
  final String roleLabel;

  const _RoleBasedUserTab({
    required this.searchController,
    required this.role,
    required this.roleLabel,
  });

  @override
  State<_RoleBasedUserTab> createState() => _RoleBasedUserTabState();
}

class _RoleBasedUserTabState extends State<_RoleBasedUserTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  List<DocumentSnapshot> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  int _pageSize = 20;
  final List<DocumentSnapshot> _pageStack = [];
  String _searchQuery = '';
  final Set<String> _selectedUserIds = {};
  
  @override
  void initState() {
    super.initState();
    _loadPageSize();
    _fetchUsers();
    widget.searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = widget.searchController.text.trim();
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
      _pageStack.clear();
      _selectedUserIds.clear();
    });
    _fetchUsers();
  }
  
  Future<void> _loadPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pageSize = prefs.getInt('userManagementPageSize') ?? 20;
    });
  }
  
  Future<void> _fetchUsers() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Query query = _firestore.collection('users').where('role', isEqualTo: widget.role);
      
      // Search by email or displayName
      if (_searchQuery.isNotEmpty) {
        if (_searchQuery.contains('@')) {
          query = query
              .where('email', isGreaterThanOrEqualTo: _searchQuery)
              .where('email', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        } else {
          query = query
              .where('displayName', isGreaterThanOrEqualTo: _searchQuery)
              .where('displayName', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        }
      } else {
        query = query.orderBy('createdAt', descending: true);
      }
      
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      
      final snapshot = await query.limit(_pageSize).get();
      
      setState(() {
        _users.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ${widget.roleLabel.toLowerCase()}: $e')),
        );
      }
    }
  }
  
  Future<void> _deleteUser(String userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'userIds': [userId]});
      
      setState(() {
        _users.removeWhere((doc) => doc.id == userId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }
  
  Future<void> _sendMessageToUser(String userId, String email) async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to $email', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': titleController.text,
        'message': messageController.text,
        'type': 'admin',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Actions bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                widget.roleLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedUserIds.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete),
                  label: Text('Delete (${_selectedUserIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _bulkMessage,
                  icon: const Icon(Icons.message),
                  label: Text('Message (${_selectedUserIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Users table
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No ${widget.roleLabel.toLowerCase()} found',
                          style: GoogleFonts.montserrat(color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selectedUserIds.length == _users.length && _users.isNotEmpty,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedUserIds.addAll(_users.map((doc) => doc.id));
                                      } else {
                                        _selectedUserIds.clear();
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('Email', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Date Created', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Last Login', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('XP', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Rank', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 100),
                              ],
                            ),
                          ),
                          // Table body
                          Expanded(
                            child: ListView.separated(
                              itemCount: _users.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final doc = _users[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final userId = doc.id;
                                final email = data['email'] ?? 'N/A';
                                final createdAt = data['createdAt'] as Timestamp?;
                                final lastLogin = data['lastLogin'] as Timestamp?;
                                final xp = data['badges']?['points'] ?? 0;
                                final rankName = data['rankName'] ?? 'Beginner';
                                
                                return ListTile(
                                  leading: Checkbox(
                                    value: _selectedUserIds.contains(userId),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedUserIds.add(userId);
                                        } else {
                                          _selectedUserIds.remove(userId);
                                        }
                                      });
                                    },
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(email, style: GoogleFonts.montserrat()),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          createdAt != null
                                              ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                                              : 'N/A',
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          lastLogin != null
                                              ? '${lastLogin.toDate().day}/${lastLogin.toDate().month}/${lastLogin.toDate().year}'
                                              : 'N/A',
                                          style: GoogleFonts.montserrat(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text('$xp', style: GoogleFonts.montserrat()),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(rankName, style: GoogleFonts.montserrat()),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.message, size: 20),
                                            onPressed: () => _sendMessageToUser(userId, email),
                                            color: const Color(0xFF2ECC71),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 20),
                                            onPressed: () => _deleteUser(userId, email),
                                            color: Colors.red,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Pagination
                          if (_hasMore || _pageStack.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_pageStack.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _previousPage,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Previous'),
                                    ),
                                  if (_hasMore)
                                    TextButton.icon(
                                      onPressed: _fetchUsers,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('Next'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
  
  void _previousPage() {
    if (_pageStack.isEmpty) return;
    setState(() {
      _lastDoc = _pageStack.removeLast();
      _users.clear();
      _hasMore = true;
    });
    _fetchUsers();
  }
  
  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Users', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete ${_selectedUserIds.length} users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final callable = _functions.httpsCallable('adminDeleteUser');
      await callable.call({'userIds': _selectedUserIds.toList()});
      
      setState(() {
        _users.removeWhere((doc) => _selectedUserIds.contains(doc.id));
        _selectedUserIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Users deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting users: $e')),
        );
      }
    }
  }
  
  Future<void> _bulkMessage() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Message to ${_selectedUserIds.length} Users', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final batch = _firestore.batch();
      for (final userId in _selectedUserIds) {
        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': userId,
          'title': titleController.text,
          'message': messageController.text,
          'type': 'admin',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      
      setState(() {
        _selectedUserIds.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending messages: $e')),
        );
      }
    }
  }
}