import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SchoolAdminTeachersPage extends StatefulWidget {
  const SchoolAdminTeachersPage({Key? key}) : super(key: key);

  @override
  State<SchoolAdminTeachersPage> createState() => _SchoolAdminTeachersPageState();
}

class _SchoolAdminTeachersPageState extends State<SchoolAdminTeachersPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _schoolName;
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchoolContext();
  }

  Future<void> _loadSchoolContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!mounted) return;
      
      final data = doc.data();
      final school = data?['school'] as String?;
      
      setState(() {
        _schoolName = school;
      });
      
      if (school != null) {
        await _loadTeachers();
      }
    } catch (e) {
      debugPrint('Error loading school context: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeachers() async {
    if (_schoolName == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      debugPrint('🔍 Loading teachers for school: $_schoolName');
      
      // Get all teachers in the school
      final teachersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      // Filter by school name flexibly
      final matchingTeachers = teachersSnap.docs.where((doc) {
        final teacherSchool = doc.data()['school'];
        return _normalizeSchoolName(teacherSchool) == _normalizeSchoolName(_schoolName);
      }).toList();

      debugPrint('📊 Found ${matchingTeachers.length} teachers in school');

      List<Map<String, dynamic>> teachersList = [];

      for (final doc in matchingTeachers) {
        final teacherData = doc.data();
        final teacherId = doc.id;

        // Get students assigned to this teacher
        final studentsSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('teacherId', isEqualTo: teacherId)
            .get();

        final studentIds = studentsSnap.docs.map((d) => d.id).toList();
        
        // Get student metrics
        int totalXP = 0;
        int totalQuestions = 0;
        
        if (studentIds.isNotEmpty) {
          // Get summaries in batches
          for (var i = 0; i < studentIds.length; i += 10) {
            final batch = studentIds.skip(i).take(10).toList();
            final summariesSnap = await FirebaseFirestore.instance
                .collection('studentSummaries')
                .where(FieldPath.documentId, whereIn: batch)
                .get();

            for (final sumDoc in summariesSnap.docs) {
              final data = sumDoc.data();
              totalXP += (data['totalXP'] as int?) ?? 0;
              totalQuestions += (data['totalQuestions'] as int?) ?? 0;
            }
          }
        }

        // Get last seen date
        final lastSeen = teacherData['lastSeen'];
        DateTime? lastSeenDate;
        if (lastSeen != null) {
          if (lastSeen is Timestamp) {
            lastSeenDate = lastSeen.toDate();
          } else if (lastSeen is String) {
            lastSeenDate = DateTime.tryParse(lastSeen);
          }
        }

        teachersList.add({
          'teacherId': teacherId,
          'teacherName': teacherData['displayName'] ?? 
              '${teacherData['firstName'] ?? ''} ${teacherData['lastName'] ?? ''}'.trim(),
          'email': teacherData['email'] ?? '',
          'phone': teacherData['phoneNumber'] ?? teacherData['phone'] ?? 'N/A',
          'class': teacherData['class'] ?? teacherData['grade'] ?? 'Unassigned',
          'studentCount': studentIds.length,
          'totalXP': totalXP,
          'totalQuestions': totalQuestions,
          'lastSeen': lastSeenDate,
          'avatar': teacherData['avatar'],
        });
      }

      // Sort alphabetically by name
      teachersList.sort((a, b) {
        final nameA = (a['teacherName'] ?? '').toString().toLowerCase();
        final nameB = (b['teacherName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _teachers = teachersList;
        _filteredTeachers = teachersList;
        _isLoading = false;
      });
      
      debugPrint('✅ Teachers loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading teachers: $e');
      setState(() => _isLoading = false);
    }
  }

  String _normalizeSchoolName(String? schoolName) {
    if (schoolName == null) return '';
    return schoolName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' school', '')
        .replaceAll(' academy', '')
        .replaceAll(' international', '')
        .trim();
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) return 'Just now';
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }

  void _filterTeachers() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredTeachers = _teachers;
      } else {
        _filteredTeachers = _teachers.where((teacher) {
          final name = (teacher['teacherName'] ?? '').toString().toLowerCase();
          final email = (teacher['email'] ?? '').toString().toLowerCase();
          final className = (teacher['class'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || className.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _copyTeacherInfo(Map<String, dynamic> teacherData) async {
    final info = '''
Teacher Information
==================
Name: ${teacherData['teacherName'] ?? 'Unknown'}
Email: ${teacherData['email'] ?? 'N/A'}
Phone: ${teacherData['phone'] ?? 'N/A'}
Class: ${teacherData['class'] ?? 'Unassigned'}
Students: ${teacherData['studentCount'] ?? 0}
Total XP: ${teacherData['totalXP'] ?? 0}
Total Questions: ${teacherData['totalQuestions'] ?? 0}
Last Seen: ${_formatLastSeen(teacherData['lastSeen'])}
''';
    
    await Clipboard.setData(ClipboardData(text: info));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Teacher info copied to clipboard',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showTeacherDetailDialog(Map<String, dynamic> teacherData) async {
    final teacherId = teacherData['teacherId'] as String?;
    if (teacherId == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: _buildTeacherDetail(teacherId, teacherData),
        ),
      ),
    );
  }

  Widget _buildTeacherDetail(String teacherId, Map<String, dynamic> teacherData) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF1A1E3F),
                backgroundImage: teacherData['avatar'] != null 
                    ? NetworkImage(teacherData['avatar']) 
                    : null,
                child: teacherData['avatar'] == null
                    ? Text(
                        (teacherData['teacherName'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacherData['teacherName'] ?? 'Unknown',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      teacherData['email'] ?? '',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () => _copyTeacherInfo(teacherData),
                tooltip: 'Copy teacher info',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 32),
          
          // Teacher Details
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Phone Number', teacherData['phone'] ?? 'N/A'),
                  _buildDetailRow('Class Assigned', teacherData['class'] ?? 'Unassigned'),
                  _buildDetailRow('Total Students', '${teacherData['studentCount'] ?? 0}'),
                  _buildDetailRow('Class Total XP', '${teacherData['totalXP'] ?? 0}'),
                  _buildDetailRow('Class Total Questions', '${teacherData['totalQuestions'] ?? 0}'),
                  _buildDetailRow(
                    'Last Seen', 
                    _formatLastSeen(teacherData['lastSeen']),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFF1A1E3F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendMessageDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String recipientType = 'all_teachers';
    String? selectedTeacherId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filteredTeachersForDialog = _filteredTeachers
              .where((t) => t['teacherId'] != null)
              .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 600,
              constraints: const BoxConstraints(maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with Navy Blue background
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
                        const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Message',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Notify your teachers',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recipient Type
                          Text(
                            'Send to',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                RadioListTile<String>(
                                  value: 'all_teachers',
                                  groupValue: recipientType,
                                  onChanged: (value) {
                                    setState(() {
                                      recipientType = value!;
                                      selectedTeacherId = null;
                                    });
                                  },
                                  title: Text(
                                    'All Teachers',
                                    style: GoogleFonts.inter(fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    'Send to all teachers in your school',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  activeColor: const Color(0xFF00C853),
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  value: 'individual',
                                  groupValue: recipientType,
                                  onChanged: (value) {
                                    setState(() {
                                      recipientType = value!;
                                    });
                                  },
                                  title: Text(
                                    'Individual Teacher',
                                    style: GoogleFonts.inter(fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    'Send to a specific teacher',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  activeColor: const Color(0xFF00C853),
                                ),
                              ],
                            ),
                          ),

                          // Teacher Selector (if individual)
                          if (recipientType == 'individual') ...[
                            const SizedBox(height: 16),
                            Text(
                              'Select Teacher',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedTeacherId,
                                  hint: Text(
                                    'Choose a teacher...',
                                    style: GoogleFonts.inter(color: Colors.grey[600]),
                                  ),
                                  items: filteredTeachersForDialog.map((teacher) {
                                    return DropdownMenuItem<String>(
                                      value: teacher['teacherId'] as String,
                                      child: Text(
                                        teacher['teacherName'] ?? 'Unknown',
                                        style: GoogleFonts.inter(fontSize: 15),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTeacherId = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Title
                          Text(
                            'Message Title',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: titleController,
                            maxLength: 200,
                            style: GoogleFonts.inter(),
                            decoration: InputDecoration(
                              hintText: 'Enter message title...',
                              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
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
                                borderSide: const BorderSide(
                                  color: Color(0xFF001F3F),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Message
                          Text(
                            'Message',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: messageController,
                            maxLines: 6,
                            maxLength: 2000,
                            style: GoogleFonts.inter(),
                            decoration: InputDecoration(
                              hintText: 'Enter your message...',
                              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
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
                                borderSide: const BorderSide(
                                  color: Color(0xFF001F3F),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.grey[700],
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
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (recipientType == 'individual' &&
                                selectedTeacherId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please select a teacher',
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context);

                            try {
                              final functions = FirebaseFunctions.instance;
                              final callable = functions.httpsCallable('sendMessage');

                              await callable.call({
                                'title': titleController.text.trim(),
                                'message': messageController.text.trim(),
                                'recipientType': recipientType,
                                if (recipientType == 'individual')
                                  'recipientId': selectedTeacherId,
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Message sent successfully!',
                                      style: GoogleFonts.inter(),
                                    ),
                                    backgroundColor: const Color(0xFF00C853),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error sending message: $e',
                                      style: GoogleFonts.inter(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          label: Text(
                            'Send Message',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    return NestedScrollView(
      headerSliverBuilder: (context, inner) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teachers',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isSmallScreen ? 20 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View and manage teachers in your school',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Search Card
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Teachers',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _filterTeachers(),
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or class...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'School: ${_schoolName ?? "Loading..."}',
                        style: GoogleFonts.montserrat(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total teachers: ${_filteredTeachers.length}',
                        style: GoogleFonts.montserrat(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Send Message Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showSendMessageDialog,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      'Send Message to Teachers',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredTeachers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No teachers found',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search query',
                        style: GoogleFonts.montserrat(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: _buildTeacherTableFromList(
                    _filteredTeachers,
                    isSmallScreen,
                  ),
                ),
    );
  }

  Widget _buildTeacherTableFromList(
    List<Map<String, dynamic>> teachers,
    bool isSmallScreen,
  ) {
    if (isSmallScreen) {
      // Mobile: card layout
      return Column(
        children: teachers.map((teacher) => _buildTeacherCard(teacher)).toList(),
      );
    }

    // Desktop: table layout
    return Container(
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
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E3F).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Email',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Phone',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Class',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Students',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Last Seen',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 40), // For action button
              ],
            ),
          ),
          // Table rows
          ...teachers.map((teacher) => _buildTeacherRow(teacher)),
        ],
      ),
    );
  }

  Widget _buildTeacherRow(Map<String, dynamic> teacher) {
    return InkWell(
      onTap: () => _showTeacherDetailDialog(teacher),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1A1E3F),
                    backgroundImage: teacher['avatar'] != null 
                        ? NetworkImage(teacher['avatar']) 
                        : null,
                    child: teacher['avatar'] == null
                        ? Text(
                            (teacher['teacherName'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      teacher['teacherName'] ?? 'Unknown',
                      style: GoogleFonts.montserrat(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                teacher['email'] ?? '',
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                teacher['phone'] ?? 'N/A',
                style: GoogleFonts.montserrat(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                teacher['class'] ?? 'Unassigned',
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${teacher['studentCount'] ?? 0}',
                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatLastSeen(teacher['lastSeen']),
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () => _showTeacherDetailDialog(teacher),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: InkWell(
        onTap: () => _showTeacherDetailDialog(teacher),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1A1E3F),
                  backgroundImage: teacher['avatar'] != null 
                      ? NetworkImage(teacher['avatar']) 
                      : null,
                  child: teacher['avatar'] == null
                      ? Text(
                          (teacher['teacherName'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['teacherName'] ?? 'Unknown',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        teacher['email'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.phone, teacher['phone'] ?? 'N/A'),
                _buildInfoChip(Icons.class_, teacher['class'] ?? 'Unassigned'),
                _buildInfoChip(Icons.people, '${teacher['studentCount']} students'),
                _buildInfoChip(
                  Icons.access_time, 
                  _formatLastSeen(teacher['lastSeen']),
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF1A1E3F)).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? const Color(0xFF1A1E3F)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: color ?? const Color(0xFF1A1E3F),
            ),
          ),
        ],
      ),
    );
  }
}
