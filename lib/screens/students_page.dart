import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/xp_service.dart';
// using native widgets for subject progress to avoid chart package compatibility issues

class StudentsPage extends StatefulWidget {
  const StudentsPage({Key? key}) : super(key: key);

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _schoolName;
  String? _teachingGrade; // teacher's class (e.g., 'JHS 1')

  String? _selectedStudentId;
  Map<String, dynamic>? _selectedStudentData;

  @override
  void initState() {
    super.initState();
    _loadTeacherContext();
  }

  Future<void> _loadTeacherContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      final data = doc.data();
      setState(() {
        _schoolName = data?['schoolName'] as String? ?? data?['school'] as String?;
        _teachingGrade = data?['teachingGrade'] as String? ?? data?['teachingGrade'] as String?;
      });
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Map<String, dynamic> studentData, String query) {
    final name = ((studentData['firstName'] ?? '') + ' ' + (studentData['lastName'] ?? '')).toString().toLowerCase();
    final email = (studentData['email'] ?? '').toString().toLowerCase();
    if (query.isEmpty) return true;
    return name.contains(query) || email.contains(query);
  }

  Future<void> _showStudentProgressDialog(String studentId, Map<String, dynamic> studentData) async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<int>(
        future: XPService().getUserTotalXP(studentId),
        builder: (context, snap) {
          final xp = snap.data ?? 0;
          return AlertDialog(
            title: Text('${studentData['firstName'] ?? ''} ${studentData['lastName'] ?? ''}', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class: ${studentData['grade'] ?? studentData['class'] ?? '-'}', style: GoogleFonts.montserrat()),
                  const SizedBox(height: 8),
                  Text('School: ${studentData['schoolName'] ?? studentData['school'] ?? '-'}', style: GoogleFonts.montserrat()),
                  const SizedBox(height: 12),
                  Text('Total XP: $xp', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD62828)),
                    child: Text('Close', style: GoogleFonts.montserrat(color: Colors.white)),
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
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();

    return NestedScrollView(
      headerSliverBuilder: (context, inner) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Students', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Search and view students in your class', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                const SizedBox(height: 16),

                // Search Card (matches Notes design language)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Search Students', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                        const SizedBox(height: 12),
                        // Show school and total students for the teacher's class
                        Text('School: ${_schoolName ?? "Loading..."}', style: GoogleFonts.montserrat()),
                        const SizedBox(height: 8),
                        FutureBuilder<int>(
                          future: _getStudentsCount(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return Text('Total students: ...', style: GoogleFonts.montserrat(color: Colors.grey[600]));
                            final count = snap.data ?? 0;
                            return Text('Total students: $count', style: GoogleFonts.montserrat(color: Colors.grey[700]));
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];

          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            // Filter by school (support both schoolName and school fields)
            final school = (data['schoolName'] ?? data['school']) as String?;
            if (_schoolName != null && school != _schoolName) return false;
            // Filter by teaching grade/class if provided
            if (_teachingGrade != null && _teachingGrade!.isNotEmpty) {
              final studentGrade = (data['grade'] ?? data['class']) as String?;
              if (studentGrade == null) return false;
              if (studentGrade.toLowerCase() != _teachingGrade!.toLowerCase()) return false;
            }
            return _matchesFilter(data, query);
          }).toList();

          if (filtered.isEmpty) return Center(child: Text('No students found', style: GoogleFonts.montserrat(color: Colors.grey[600])));

          // default select first if none
          if (_selectedStudentId == null && filtered.isNotEmpty) {
            _selectedStudentId = filtered.first.id;
            _selectedStudentData = filtered.first.data() as Map<String, dynamic>;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              // Always show a single list/table of students for teachers.
              // The previous detail pane has been removed as requested.
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: _buildStudentTable(filtered),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStudentList(List<QueryDocumentSnapshot> filtered) {
    // kept for backwards compatibility if needed elsewhere
    return _buildStudentTable(filtered);
  }

  Widget _buildStudentTable(List<QueryDocumentSnapshot> filtered) {
    // Render a scrollable table-like list showing the required columns:
    // Name | Class | Email | Rank | XP | Subjects Solved From | Total Questions Solved
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
        child: Column(
          children: [
                // Header row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: Colors.grey.shade100,
              child: Row(
                children: const [
                  SizedBox(width: 280, child: Text('Student', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 100, child: Text('Class', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 260, child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 100, child: Text('Rank', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 100, child: Text('XP', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 160, child: Text('Subject Solved', style: TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 160, child: Text('Questions Solved', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const Divider(height: 1),
            // Rows
            ...filtered.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              final grade = data['grade'] ?? data['class'] ?? '';
              final email = data['email'] ?? '';

              return FutureBuilder<Map<String, dynamic>>(
                future: _buildStudentSummary(d.id),
                builder: (context, snap) {
                  final summary = snap.data;
                  final rank = summary != null ? (summary['rank'] ?? '-') : '-';
                  final xp = summary != null ? (summary['xp']?.toString() ?? '-') : '-';
                  final subjects = summary != null ? (summary['subjects']?.join(', ') ?? '-') : '-';
                  final totalQuestions = summary != null ? (summary['totalQuestions']?.toString() ?? '-') : '-';

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: Row(children: [
                            CircleAvatar(radius: 18, backgroundImage: (data['profileImageUrl'] as String?)?.isNotEmpty == true ? NetworkImage(data['profileImageUrl']) : null, child: (data['profileImageUrl'] == null) ? Text((data['firstName'] ?? '?').toString().substring(0,1).toUpperCase()) : null),
                            const SizedBox(width: 12),
                            Expanded(child: Text(name.isNotEmpty ? name : email, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600))),
                          ]),
                        ),
                        SizedBox(width: 100, child: Text(grade ?? '', style: GoogleFonts.montserrat())),
                        SizedBox(width: 260, child: Text(email, style: GoogleFonts.montserrat(color: Colors.grey[700]))),
                        SizedBox(width: 100, child: Text(rank.toString(), style: GoogleFonts.montserrat())),
                        SizedBox(width: 100, child: Text(xp.toString(), style: GoogleFonts.montserrat())),
                        SizedBox(width: 160, child: Text((summary != null ? (summary['subjects'] is List ? (summary['subjects'] as List).length : (summary['subjectsCount'] ?? '-')) : '-').toString(), style: GoogleFonts.montserrat())),
                        SizedBox(width: 160, child: Text(totalQuestions.toString(), style: GoogleFonts.montserrat())),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<int> _getStudentsCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      final school = data?['schoolName'] ?? data?['school'];
      final grade = data?['teachingGrade'] ?? data?['teachingGrade'] ?? data?['grade'] ?? data?['class'];
      if (school == null || grade == null) return 0;
      final qs = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('schoolName', isEqualTo: school).where('grade', isEqualTo: grade).get();
      return qs.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Build a small summary for each student: XP, rank (if available), subjects list and total questions solved.
  Future<Map<String, dynamic>> _buildStudentSummary(String studentId) async {
    final xp = await XPService().getUserTotalXP(studentId);
    // Fetch quizzes for this student (limited to 500 for performance)
    final qs = await FirebaseFirestore.instance.collection('quizzes').where('userId', isEqualTo: studentId).limit(500).get();
    final subjectsSet = <String>{};
    int totalQuestions = 0;
    for (final q in qs.docs) {
      final data = q.data() as Map<String, dynamic>;
      final subject = (data['subject'] ?? data['collectionName'] ?? '').toString();
      if (subject.isNotEmpty) subjectsSet.add(subject);
      final tq = (data['totalQuestions'] as int?) ?? (data['total'] as int?) ?? 0;
      totalQuestions += tq;
    }
    // Attempt to get rank from a user doc field if present
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
    final userData = userDoc.data();
    final rank = userData != null ? (userData['rankName'] ?? userData['rank'] ?? '-') : '-';

    return {
      'xp': xp,
      'rank': rank,
      'subjects': subjectsSet.toList(),
      'totalQuestions': totalQuestions,
    };
  }

  Widget _buildStudentDetail(String? selectedId, Map<String, dynamic>? selectedData) {
    if (selectedId == null || selectedData == null) {
      return Center(child: Text('Select a student to view progress', style: GoogleFonts.montserrat(color: Colors.grey[600])));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: (selectedData['profileImageUrl'] as String?)?.isNotEmpty == true
                    ? NetworkImage(selectedData['profileImageUrl']) as ImageProvider
                    : null,
                child: (selectedData['profileImageUrl'] as String?) == null
                    ? Text((selectedData['firstName'] ?? '?').toString().substring(0,1).toUpperCase(), style: GoogleFonts.montserrat(fontSize: 20))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selectedData['firstName'] ?? ''} ${selectedData['lastName'] ?? ''}', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Class: ${selectedData['grade'] ?? selectedData['class'] ?? '-'}', style: GoogleFonts.montserrat()),
                    Text('School: ${selectedData['schoolName'] ?? selectedData['school'] ?? '-'}', style: GoogleFonts.montserrat()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<int>(
            future: XPService().getUserTotalXP(selectedId),
            builder: (context, snap) {
              final xp = snap.data ?? 0;
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress Overview', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Total XP: $xp', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Recent activity: (tap for details)', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Recent quizzes snippet (lightweight): show last 5 quiz docs if available
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('quizzes')
                .where('userId', isEqualTo: selectedId)
                .orderBy('completedAt', descending: true)
                .limit(5)
                .get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox();
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Text('No recent quizzes', style: GoogleFonts.montserrat(color: Colors.grey[600]));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Quizzes', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final score = data['score'] ?? data['percent'] ?? '-';
                    final title = data['title'] ?? data['collectionName'] ?? 'Quiz';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(title.toString(), style: GoogleFonts.montserrat()),
                      trailing: Text(score.toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Per-subject progress chart
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('quizzes')
                .where('userId', isEqualTo: selectedId)
                .limit(200)
                .get(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox();
              final quizDocs = snap.data?.docs ?? [];
              if (quizDocs.isEmpty) return Text('No subject progress available', style: GoogleFonts.montserrat(color: Colors.grey[600]));

              // Compute average percent per subject
              final Map<String, List<double>> subjectScores = {};
              for (final q in quizDocs) {
                final data = q.data() as Map<String, dynamic>;
                final subject = (data['subject'] ?? data['collectionName'] ?? 'Misc').toString();
                double? percent;
                if (data['percent'] != null) {
                  percent = (data['percent'] is num) ? (data['percent'] as num).toDouble() : double.tryParse(data['percent'].toString());
                } else if (data['score'] != null && data['total'] != null) {
                  final score = (data['score'] as num).toDouble();
                  final total = (data['total'] as num).toDouble();
                  if (total > 0) percent = (score / total) * 100;
                } else if (data['score'] != null) {
                  final score = (data['score'] as num).toDouble();
                  percent = score; // assume already percentage
                }
                if (percent == null) continue;
                subjectScores.putIfAbsent(subject, () => []).add(percent.clamp(0, 100));
              }

              final subjects = subjectScores.keys.toList();
              final averages = subjects.map((s) {
                final list = subjectScores[s]!;
                final avg = list.reduce((a, b) => a + b) / list.length;
                return avg;
              }).toList();

              if (subjects.isEmpty) return Text('No subject progress available', style: GoogleFonts.montserrat(color: Colors.grey[600]));

              // Render per-subject horizontal progress bars (mobile-friendly)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject Progress (avg %)', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(subjects.length, (i) {
                    final label = subjects[i];
                    final avg = averages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(label, style: GoogleFonts.montserrat(fontSize: 14))),
                              const SizedBox(width: 8),
                              Text('${avg.toStringAsFixed(0)}%', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (avg / 100).clamp(0.0, 1.0),
                              minHeight: 10,
                              color: const Color(0xFFD62828),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

