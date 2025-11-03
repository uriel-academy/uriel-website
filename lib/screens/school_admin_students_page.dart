import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class SchoolAdminStudentsPage extends StatefulWidget {
  const SchoolAdminStudentsPage({Key? key}) : super(key: key);

  @override
  State<SchoolAdminStudentsPage> createState() => _SchoolAdminStudentsPageState();
}

class _SchoolAdminStudentsPageState extends State<SchoolAdminStudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _schoolName;
  String? _selectedClass;
  List<String> _availableClasses = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
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
        await _loadStudents();
        await _loadAvailableClasses();
      }
    } catch (e) {
      debugPrint('Error loading school context: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableClasses() async {
    if (_schoolName == null) return;
    
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: _schoolName)
          .get();

      final classesSet = <String>{};
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final className = data['class'];
        if (className != null && className.toString().isNotEmpty) {
          classesSet.add(className.toString());
        }
      }

      if (mounted) {
        setState(() {
          _availableClasses = classesSet.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadStudents() async {
    if (_schoolName == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get all students in the school
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: _schoolName);

      if (_selectedClass != null) {
        query = query.where('class', isEqualTo: _selectedClass);
      }

      final studentsSnap = await query.get();
      final studentIds = studentsSnap.docs.map((d) => d.id).toList();

      if (studentIds.isEmpty) {
        setState(() {
          _students = [];
          _filteredStudents = [];
          _isLoading = false;
        });
        return;
      }

      // Get student summaries in batches
      List<Map<String, dynamic>> studentsList = [];
      for (var i = 0; i < studentIds.length; i += 10) {
        final batch = studentIds.skip(i).take(10).toList();
        final summariesSnap = await FirebaseFirestore.instance
            .collection('studentSummaries')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in summariesSnap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['studentId'] = doc.id; // Ensure studentId is set
          studentsList.add(data);
        }
      }

      // Sort alphabetically by first name
      studentsList.sort((a, b) {
        final nameA = (a['firstName'] ?? a['studentName'] ?? '').toString().toLowerCase();
        final nameB = (b['firstName'] ?? b['studentName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _students = studentsList;
        _filteredStudents = studentsList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading students: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((student) {
          final name = (student['studentName'] ?? '').toString().toLowerCase();
          final email = (student['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _showStudentDetailDialog(Map<String, dynamic> studentData) async {
    final studentId = studentData['studentId'] as String?;
    if (studentId == null) return;

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
          child: _buildStudentDetail(studentId, studentData),
        ),
      ),
    );
  }

  Widget _buildStudentDetail(String studentId, Map<String, dynamic> studentData) {
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
                  (studentData['studentName'] ?? '?')[0].toUpperCase(),
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
                      studentData['studentName'] ?? 'Unknown',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      studentData['email'] ?? '',
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
          
          // Student Details
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Class', studentData['class'] ?? 'N/A'),
                  _buildDetailRow('Current Rank', studentData['rankName'] ?? 'Learner'),
                  _buildDetailRow('Total XP', '${studentData['xp'] ?? 0}'),
                  _buildDetailRow('Questions Answered', '${studentData['questionsAnswered'] ?? 0}'),
                  _buildDetailRow('Accuracy', studentData['accuracy'] != null ? '${studentData['accuracy'].toStringAsFixed(1)}%' : 'N/A'),
                  _buildDetailRow('Subjects Solved', '${studentData['subjectsSolved'] ?? 0}'),
                  _buildDetailRow('Teacher', studentData['teacherName'] ?? 'Unassigned'),
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
            width: 150,
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
                  'Students',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isSmallScreen ? 20 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search and view students in your school',
                  style: GoogleFonts.montserrat(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Search and Filter Card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Search Students',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Class filter dropdown
                          if (_availableClasses.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedClass,
                                  hint: Text(
                                    'All Classes',
                                    style: GoogleFonts.montserrat(fontSize: 14),
                                  ),
                                  icon: const Icon(Icons.filter_list, size: 18),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(
                                        'All Classes',
                                        style: GoogleFonts.montserrat(fontSize: 14),
                                      ),
                                    ),
                                    ..._availableClasses.map((className) {
                                      return DropdownMenuItem<String>(
                                        value: className,
                                        child: Text(
                                          className,
                                          style: GoogleFonts.montserrat(fontSize: 14),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedClass = value);
                                    _loadStudents();
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _filterStudents(),
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
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
                        'Total students: ${_filteredStudents.length}',
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
          : _filteredStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No students found',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or search query',
                        style: GoogleFonts.montserrat(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: _buildStudentTableFromList(
                    _filteredStudents,
                    isSmallScreen,
                  ),
                ),
    );
  }

  Widget _buildStudentTableFromList(
    List<Map<String, dynamic>> students,
    bool isSmallScreen,
  ) {
    if (isSmallScreen) {
      // Mobile: card layout
      return Column(
        children: students.map((student) => _buildStudentCard(student)).toList(),
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
                  flex: 2,
                  child: Text(
                    'Rank',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'XP',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 40), // For action button
              ],
            ),
          ),
          // Table rows
          ...students.map((student) => _buildStudentRow(student)),
        ],
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student) {
    return InkWell(
      onTap: () => _showStudentDetailDialog(student),
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
                      (student['studentName'] ?? '?')[0].toUpperCase(),
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
                      student['studentName'] ?? 'Unknown',
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
                student['class'] ?? 'N/A',
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                student['rankName'] ?? 'Learner',
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${student['xp'] ?? 0}',
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
              onPressed: () => _showStudentDetailDialog(student),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
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
        onTap: () => _showStudentDetailDialog(student),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF1A1E3F),
              child: Text(
                (student['studentName'] ?? '?')[0].toUpperCase(),
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
                    student['studentName'] ?? 'Unknown',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student['class'] ?? 'N/A'} • ${student['rankName'] ?? 'Learner'}',
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
                  '${student['xp'] ?? 0} XP',
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
