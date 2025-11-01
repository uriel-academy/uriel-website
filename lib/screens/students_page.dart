import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/xp_service.dart';
import '../services/leaderboard_rank_service.dart';
import '../services/class_aggregates_service.dart';
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
  // Pagination & caching for server-side aggregates
  final Map<String, dynamic> _pageCache = {}; // key: cursorKey -> result map
  String _currentCursorKey = 'start';
  final Map<String, String?> _nextCursorByKey = {};
  final int _pageSize = 50;
  bool _isLoadingPage = false;
  Future<void>? _pageFuture;

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
        _teachingGrade = data?['teachingGrade'] as String? ?? data?['grade'] as String? ?? data?['class'] as String?;
      });
      // kick off initial page load
      _pageFuture = _loadPage(null);
      setState(() {});
    } catch (e) {
      // ignore
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Show detailed student metrics dialog
  Future<void> _showStudentDetailDialog(Map<String, dynamic> studentData) async {
    final studentId = studentData['uid'] as String?;
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

  @override
  Widget build(BuildContext context) {
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
                        FutureBuilder<void>(
                          future: _pageFuture,
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return Text('Total students: ...', style: GoogleFonts.montserrat(color: Colors.grey[600]));
                            final page = _pageCache[_currentCursorKey] as Map<String, dynamic>?;
                            final count = page?['totalCount'] as int? ?? 0;
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
      body: FutureBuilder<void>(
        future: _pageFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final page = _pageCache[_currentCursorKey] as Map<String, dynamic>?;
          final allStudents = (page != null ? page['students'] as List<dynamic> : <dynamic>[]);
          
          // Filter students based on search query
          final query = _searchController.text.toLowerCase().trim();
          final students = query.isEmpty 
            ? allStudents 
            : allStudents.where((s) {
                final data = s as Map<String, dynamic>;
                final name = (data['displayName'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(query) || email.contains(query);
              }).toList();

          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    query.isEmpty ? 'No students found' : 'No students match "$query"',
                    style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 16),
                  ),
                  if (query.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      child: Text('Clear search', style: GoogleFonts.montserrat(color: const Color(0xFFD62828))),
                    ),
                  ],
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(child: _buildStudentTableFromList(students)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _prevPage,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
                          child: Text('Prev', style: GoogleFonts.montserrat()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
                          child: Text('Next', style: GoogleFonts.montserrat(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadPage(String? pageCursor) async {
    if (_isLoadingPage) return;
    _isLoadingPage = true;
    final key = pageCursor ?? 'start';
    try {
      // Skip if cached
      if (_pageCache.containsKey(key)) {
        _isLoadingPage = false;
        return;
      }

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('getClassAggregates');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final callData = <String, dynamic>{
        'pageSize': _pageSize,
        'pageCursor': pageCursor,
        'includeCount': true,
      };

      // Prefer teacherId when available
      final meDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final me = meDoc.data() ?? {};
      if ((me['teacherId'] ?? me['role']) == 'teacher') {
        callData['teacherId'] = user.uid;
      } else if (_schoolName != null && _teachingGrade != null) {
        callData['school'] = _schoolName;
        callData['grade'] = _teachingGrade;
      }

      final resp = await callable.call(callData);
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return;

      _pageCache[key] = data;
      _nextCursorByKey[key] = data['nextPageCursor'] as String?;
      // set current cursor key if starting
      _currentCursorKey = key;
    } catch (e, st) {
      // Log errors so we can see permission / callable problems in the console
      // (helps debugging when teacher token hasn't refreshed or rules block access)
      // ignore: avoid_print
      print('getClassAggregates error: $e\n$st');
      // leave cache empty
    } finally {
      _isLoadingPage = false;
    }
  }

  Future<void> _nextPage() async {
    final next = _nextCursorByKey[_currentCursorKey];
    if (next == null) return;
    // store current key in history with simple naming
    final nextKey = next;
    _pageFuture = _loadPage(next);
    setState(() {});
    await _pageFuture;
    // switch to new page
    _currentCursorKey = nextKey;
    setState(() {});
  }

  Future<void> _prevPage() async {
    // naive previous: reset to start
    if (_currentCursorKey == 'start') return;
    _currentCursorKey = 'start';
    // ensure start loaded
    _pageFuture = _loadPage(null);
    setState(() {});
    await _pageFuture;
  }

  Widget _buildStudentTableFromList(List<dynamic> students) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              SizedBox(width: 50, child: Text('No.', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 3, child: Text('Student', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 1, child: Text('XP', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 1, child: Text('Questions', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 1, child: Text('Accuracy', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 1, child: Text('Subjects', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
              Expanded(flex: 1, child: Text('Rank', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13))),
            ],
          ),
        ),
            const Divider(height: 1),
            ...students.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              final data = s as Map<String, dynamic>;
              
              // Extract comprehensive data - now properly using API response
              final name = (data['displayName'] ?? '') as String;
              final email = (data['email'] ?? '') as String;
              final rank = data['rank'] ?? '-';
              final xp = data['totalXP'] ?? 0;
              
              // Get accuracy directly from API response (now calculated in Cloud Function)
              double? accuracy;
              if (data['avgPercent'] != null) {
                final avgPct = data['avgPercent'];
                accuracy = (avgPct is num) ? avgPct.toDouble() : double.tryParse(avgPct.toString());
              }
              
              final subjectsCount = data['subjectsSolved'] ?? 0;
              final questionsCount = data['questionsSolved'] ?? 0;

              return InkWell(
                onTap: () => _showStudentDetailDialog(data),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFD62828).withOpacity(0.1),
                            backgroundImage: (data['avatar'] as String?)?.isNotEmpty == true ? NetworkImage((data['avatar'] as String)) : null,
                            child: (data['avatar'] as String?) == null 
                              ? Text(
                                  (name.isNotEmpty ? name[0] : '?').toUpperCase(), 
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFD62828))
                                ) 
                              : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? name : email, 
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (name.isNotEmpty)
                                  Text(
                                    email, 
                                    style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          xp.toString(), 
                          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: const Color(0xFFD62828))
                        )
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          questionsCount.toString(), 
                          style: GoogleFonts.montserrat()
                        )
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          accuracy != null ? '${accuracy.toStringAsFixed(1)}%' : '-', 
                          style: GoogleFonts.montserrat(
                            color: accuracy != null && accuracy >= 70 ? Colors.green : (accuracy != null && accuracy >= 50 ? Colors.orange : Colors.grey[700]),
                            fontWeight: accuracy != null && accuracy >= 70 ? FontWeight.w600 : FontWeight.normal,
                          )
                        )
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          subjectsCount.toString(), 
                          style: GoogleFonts.montserrat()
                        )
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: rank.toString() != '-' ? const Color(0xFFD62828).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rank.toString(), 
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: rank.toString() != '-' ? const Color(0xFFD62828) : Colors.grey[700],
                            )
                          ),
                        )
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        const Divider(height: 1),
      ],
    );
  }



  Widget _buildStudentDetail(String? selectedId, Map<String, dynamic>? selectedData) {
    if (selectedId == null || selectedData == null) {
      return Center(child: Text('Select a student to view progress', style: GoogleFonts.montserrat(color: Colors.grey[600])));
    }

    return Column(
      children: [
        // Header with close button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD62828), Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                backgroundImage: (selectedData['avatar'] as String?)?.isNotEmpty == true
                    ? NetworkImage(selectedData['avatar']) as ImageProvider
                    : null,
                child: (selectedData['avatar'] as String?) == null
                    ? Text(
                        (selectedData['displayName']?.toString().isNotEmpty == true 
                          ? selectedData['displayName'][0] 
                          : '?').toUpperCase(), 
                        style: GoogleFonts.montserrat(fontSize: 20, color: const Color(0xFFD62828), fontWeight: FontWeight.bold)
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedData['displayName'] ?? '-', 
                      style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedData['email'] ?? '-',
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key metrics grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total XP',
                        (selectedData['totalXP'] ?? 0).toString(),
                        Icons.stars,
                        const Color(0xFFD62828),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Questions',
                        (selectedData['questionsSolved'] ?? 0).toString(),
                        Icons.quiz,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Accuracy',
                        () {
                          double? accuracy;
                          if (selectedData['avgPercent'] != null) {
                            final avgPct = selectedData['avgPercent'];
                            accuracy = (avgPct is num) ? avgPct.toDouble() : double.tryParse(avgPct.toString());
                          }
                          return accuracy != null && accuracy > 0 ? '${accuracy.toStringAsFixed(1)}%' : '-';
                        }(),
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Subjects',
                        (selectedData['subjectsSolved'] ?? 0).toString(),
                        Icons.library_books,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                // Recent quizzes
                Text('Recent Quizzes', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('quizzes')
                      .where('userId', isEqualTo: selectedId)
                      .orderBy('completedAt', descending: true)
                      .limit(5)
                      .get(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('No recent quizzes', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final score = data['score'] ?? data['percent'] ?? '-';
                        final title = data['title'] ?? data['collectionName'] ?? 'Quiz';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.toString(), 
                                  style: GoogleFonts.montserrat(fontSize: 13),
                                ),
                              ),
                              Text(
                                score.toString(), 
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: const Color(0xFFD62828)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Subject progress
                Text('Subject Progress', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('quizzes')
                      .where('userId', isEqualTo: selectedId)
                      .limit(200)
                      .get(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final quizDocs = snap.data?.docs ?? [];
                    if (quizDocs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('No subject progress available', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                      );
                    }

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
                        percent = score;
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

                    if (subjects.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('No subject progress available', style: GoogleFonts.montserrat(color: Colors.grey[600])),
                      );
                    }

                    return Column(
                      children: List.generate(subjects.length, (i) {
                        final label = subjects[i];
                        final avg = averages[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(label, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600))),
                                  const SizedBox(width: 8),
                                  Text('${avg.toStringAsFixed(1)}%', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: const Color(0xFFD62828))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (avg / 100).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  color: const Color(0xFFD62828),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

