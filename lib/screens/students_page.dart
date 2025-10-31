import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/xp_service.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({Key? key}) : super(key: key);

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _schoolName;
  String? _teachingGrade; // teacher's class (e.g., 'JHS 1')

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
      final data = doc.data() as Map<String, dynamic>?;
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
                  // We could fetch more detailed metrics (avg score, streak) by querying quizzes. Keep minimal for performance.
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2)))],
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
                      Row(
                        children: [
                          Expanded(child: Text('School: ${_schoolName ?? "Loading..."}', style: GoogleFonts.montserrat())),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Class: ${_teachingGrade ?? "All"}', style: GoogleFonts.montserrat())),
                        ],
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

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final d = filtered[i];
              final data = d.data() as Map<String, dynamic>;
              final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              final grade = data['grade'] ?? data['class'] ?? '';
              final avatar = data['profileImageUrl'] as String?;
              return ListTile(
                onTap: () => _showStudentProgressDialog(d.id, data),
                leading: CircleAvatar(backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar == null ? Text((data['firstName'] ?? '?').toString().substring(0,1).toUpperCase()) : null),
                title: Text(name.isNotEmpty ? name : (data['email'] ?? 'Unknown'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                subtitle: Text(grade ?? '', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFD62828)),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemCount: filtered.length,
          );
        },
      ),
    );
  }
}
