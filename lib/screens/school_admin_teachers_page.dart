import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
      // Get all teachers in the school
      final teachersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('school', isEqualTo: _schoolName)
          .get();

      List<Map<String, dynamic>> teachersList = [];

      for (final doc in teachersSnap.docs) {
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
        double totalAccuracy = 0;
        int studentsWithAccuracy = 0;
        
        if (studentIds.isNotEmpty) {
          // Get summaries in batches
          for (var i = 0; i < studentIds.length; i += 10) {
            final batch = studentIds.skip(i).take(10).toList();
            final summariesSnap = await FirebaseFirestore.instance
                .collection('studentSummaries')
                .where('studentId', whereIn: batch)
                .get();

            for (final sumDoc in summariesSnap.docs) {
              final data = sumDoc.data();
              totalXP += (data['xp'] as int?) ?? 0;
              totalQuestions += (data['questionsAnswered'] as int?) ?? 0;
              
              final acc = data['accuracy'];
              if (acc != null && acc > 0) {
                totalAccuracy += (acc is num) ? acc.toDouble() : 0;
                studentsWithAccuracy++;
              }
            }
          }
        }

        final avgAccuracy = studentsWithAccuracy > 0 
            ? totalAccuracy / studentsWithAccuracy 
            : 0.0;

        teachersList.add({
          'teacherId': teacherId,
          'teacherName': teacherData['displayName'] ?? 
              '${teacherData['firstName'] ?? ''} ${teacherData['lastName'] ?? ''}'.trim(),
          'email': teacherData['email'],
          'class': teacherData['class'] ?? teacherData['grade'] ?? 'Unassigned',
          'studentCount': studentIds.length,
          'totalXP': totalXP,
          'totalQuestions': totalQuestions,
          'avgAccuracy': avgAccuracy,
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
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      setState(() => _isLoading = false);
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
                child: Text(
                  (teacherData['teacherName'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  _buildDetailRow('Class', teacherData['class'] ?? 'Unassigned'),
                  _buildDetailRow('Total Students', '${teacherData['studentCount'] ?? 0}'),
                  _buildDetailRow('Total XP (Class)', '${teacherData['totalXP'] ?? 0}'),
                  _buildDetailRow('Total Questions (Class)', '${teacherData['totalQuestions'] ?? 0}'),
                  _buildDetailRow(
                    'Average Accuracy (Class)', 
                    teacherData['avgAccuracy'] != null && teacherData['avgAccuracy'] > 0
                        ? '${teacherData['avgAccuracy'].toStringAsFixed(1)}%'
                        : 'N/A'
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
                  flex: 3,
                  child: Text(
                    'Name',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
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
                    'Total XP',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
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
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1A1E3F),
                    child: Text(
                      (teacher['teacherName'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                teacher['class'] ?? 'Unassigned',
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${teacher['studentCount'] ?? 0}',
                style: GoogleFonts.montserrat(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${teacher['totalXP'] ?? 0}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD62828),
                ),
                textAlign: TextAlign.right,
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
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1A1E3F),
              child: Text(
                (teacher['teacherName'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher['teacherName'] ?? 'Unknown',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${teacher['class'] ?? 'Unassigned'} • ${teacher['studentCount'] ?? 0} students',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${teacher['totalXP'] ?? 0} XP',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD62828),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
