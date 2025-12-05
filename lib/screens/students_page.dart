import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Pagination & caching for server-side aggregates
  final Map<String, dynamic> _pageCache = {}; // key: cursorKey -> result map
  String _currentCursorKey = 'start';
  final Map<String, String?> _nextCursorByKey = {};
  final int _pageSize = 10;  // Limit to 10 students per page
  bool _isLoadingPage = false;
  Future<void>? _pageFuture;
  // Mobile page controller for horizontal swiping between pages
  late final PageController _mobilePageController;

  @override
  void initState() {
    super.initState();
    _loadTeacherContext();
    _mobilePageController = PageController();
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
    _mobilePageController.dispose();
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
                Text('Students', style: GoogleFonts.playfairDisplay(fontSize: isSmallScreen ? 20 : 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Search and view students in your class', style: GoogleFonts.montserrat(fontSize: isSmallScreen ? 13 : 14, color: Colors.grey[600])),
                const SizedBox(height: 16),

                // Search Card (matches Notes design language)
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
          
          // Sort students alphabetically by name
          students.sort((a, b) {
            final nameA = ((a as Map<String, dynamic>)['displayName'] ?? '').toString().toLowerCase();
            final nameB = ((b as Map<String, dynamic>)['displayName'] ?? '').toString().toLowerCase();
            return nameA.compareTo(nameB);
          });

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
              // Mobile: show stacked cards for each student to avoid horizontal overflow
              if (isSmallScreen) {
                // Mobile: two horizontal pages - Students list and Class Overview
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Small segmented control to switch pages
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _mobilePageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(child: Text('Students', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _mobilePageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(child: Text('Overview', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: PageView(
                          controller: _mobilePageController,
                          children: [
                            // Page 0: Students list (vertical scroll)
                            ListView.separated(
                              itemCount: students.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final s = students[index] as Map<String, dynamic>;
                                return _buildStudentCardMobile(index, s);
                              },
                            ),
                            // Page 1: Class overview - aggregated metrics
                            SingleChildScrollView(
                              child: _buildClassOverview(students, (page?['totalCount'] as int?) ?? students.length),
                            ),
                          ],
                        ),
                      ),
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
              }

              // Desktop / large screens: keep table layout
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildStudentTableFromList(students),
                      ),
                    ),
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
      debugPrint('getClassAggregates error: $e\n$st');
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
              final rank = data['rank'] ?? '-';  // API returns rank name in 'rank' field
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
                            backgroundColor: const Color(0xFFD62828).withValues(alpha: 0.1),
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
                            color: rank.toString() != '-' ? const Color(0xFFD62828).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
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

  // Mobile card for a single student (compact)
  Widget _buildStudentCardMobile(int index, Map<String, dynamic> data) {
    final name = (data['displayName'] ?? '') as String;
    final email = (data['email'] ?? '') as String;
    final xp = data['totalXP'] ?? 0;
    final questionsCount = data['questionsSolved'] ?? 0;
    double? accuracy;
    if (data['avgPercent'] != null) {
      final avgPct = data['avgPercent'];
      accuracy = (avgPct is num) ? avgPct.toDouble() : double.tryParse(avgPct.toString());
    }
    final subjectsCount = data['subjectsSolved'] ?? 0;
    final rank = data['rank'] ?? '-';

    return InkWell(
      onTap: () => _showStudentDetailDialog(data),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFD62828).withValues(alpha: 0.08),
                  backgroundImage: (data['avatar'] as String?)?.isNotEmpty == true ? NetworkImage((data['avatar'] as String)) : null,
                  child: (data['avatar'] as String?) == null
                      ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFD62828)))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : email, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                      if (name.isNotEmpty) Text(email, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('XP', style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(xp.toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFD62828))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (accuracy != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Text('${accuracy.toStringAsFixed(1)}% acc', style: GoogleFonts.montserrat(fontSize: 12)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Text('$questionsCount q', style: GoogleFonts.montserrat(fontSize: 12)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Text('$subjectsCount sub', style: GoogleFonts.montserrat(fontSize: 12)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rank.toString() != '-' ? const Color(0xFFD62828).withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(rank.toString(), style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Class overview aggregated from the current students page
  Widget _buildClassOverview(List<dynamic> students, int totalCount) {
    // compute simple aggregates
    final totalXP = students.fold<int>(0, (sum, s) => sum + ((s as Map<String, dynamic>)['totalXP'] as int? ?? 0));
    final avgXP = students.isNotEmpty ? (totalXP / students.length).round() : 0;
    double totalAccuracy = 0;
    int accCount = 0;
    for (var s in students) {
      final data = s as Map<String, dynamic>;
      if (data['avgPercent'] != null) {
        final pct = data['avgPercent'];
        final val = (pct is num) ? pct.toDouble() : double.tryParse(pct.toString()) ?? 0.0;
        totalAccuracy += val;
        accCount++;
      }
    }
    final avgAccuracy = accCount > 0 ? (totalAccuracy / accCount) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class Overview', style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSectionCard(
          'Quick Summary',
          Icons.group,
          Colors.blue,
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPerformanceStat('Total Students', '$totalCount', Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPerformanceStat('Average XP', '$avgXP', Colors.purple)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPerformanceStat('Avg Accuracy', '${avgAccuracy.toStringAsFixed(1)}%', Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPerformanceStat('Students on Rank', '${students.where((s) => ((s as Map<String,dynamic>)["rank"] ?? "-") != "-").length}', Colors.orange)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Top students list snapshot
        Text('Top students (page)', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...students.take(5).map((s) {
          final data = s as Map<String, dynamic>;
          final name = (data['displayName'] ?? '') as String;
          final xp = data['totalXP'] ?? 0;
          final acc = data['avgPercent'] ?? 0;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundImage: (data['avatar'] as String?)?.isNotEmpty == true ? NetworkImage(data['avatar']) : null, child: (data['avatar'] as String?) == null ? Text((name.isNotEmpty ? name[0] : '?').toUpperCase()) : null),
            title: Text(name.isNotEmpty ? name : (data['email'] ?? '-'), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            subtitle: Text('XP: $xp • ${acc is num ? (acc).toStringAsFixed(1) : acc}%'),
          );
        }).toList(),
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
                      style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
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
                
                const SizedBox(height: 24),
                
                // NEW: Overall Performance
                _buildOverallPerformance(selectedId),
                
                const SizedBox(height: 20),
                
                // NEW: Subject Mastery
                _buildSubjectMastery(selectedId),
                
                const SizedBox(height: 20),
                
                // NEW: BECE Past Questions Performance
                _buildBecePastQuestions(selectedId),
                
                const SizedBox(height: 20),
                
                // NEW: Trivia Performance
                _buildTriviaPerformance(selectedId),
                
                const SizedBox(height: 20),
                
                // NEW: Study Time by Subjects
                _buildStudyTimeBySubjects(selectedId),
                
                const SizedBox(height: 20),
                // Recent quizzes
                Text('Recent Quizzes', style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('quizzes')
                      .where('userId', isEqualTo: selectedId)
                      .orderBy('timestamp', descending: true)
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
                        final percentage = (data['percentage'] as num?)?.toDouble() ?? 0.0;
                        final title = data['title'] ?? data['collectionName'] ?? data['subject'] ?? 'Quiz';
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
                                '${percentage.toStringAsFixed(1)}%', 
                                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: const Color(0xFFD62828)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  // NEW: Overall Performance Section
  Widget _buildOverallPerformance(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionCard(
            'Overall Performance',
            Icons.analytics,
            Colors.purple,
            const Text('No performance data available', style: TextStyle(color: Colors.grey)),
          );
        }

        final quizzes = snapshot.data!.docs;
        final scores = quizzes.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['percentage'] ?? 0).toDouble();
        }).toList();

        final avgScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
        final excellent = scores.where((s) => s >= 80).length;
        final good = scores.where((s) => s >= 60 && s < 80).length;
        final needsImprovement = scores.where((s) => s < 60).length;

        // Calculate trend (last 5 vs previous 5)
        String trend = 'Stable';
        Color trendColor = Colors.orange;
        IconData trendIcon = Icons.trending_flat;
        
        if (scores.length >= 10) {
          final recent5 = scores.sublist(0, 5).reduce((a, b) => a + b) / 5;
          final previous5 = scores.sublist(5, 10).reduce((a, b) => a + b) / 5;
          if (recent5 > previous5 + 5) {
            trend = 'Improving';
            trendColor = Colors.green;
            trendIcon = Icons.trending_up;
          } else if (recent5 < previous5 - 5) {
            trend = 'Declining';
            trendColor = Colors.red;
            trendIcon = Icons.trending_down;
          }
        }

        return _buildSectionCard(
          'Overall Performance',
          Icons.analytics,
          Colors.purple,
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceStat('Average Score', '${avgScore.toStringAsFixed(1)}%', Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceStat('Total Quizzes', '${quizzes.length}', Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trendColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(trendIcon, color: trendColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Trend: $trend',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceDistribution('Excellent (≥80%)', excellent, Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPerformanceDistribution('Good (60-79%)', good, Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPerformanceDistribution('Needs Work (<60%)', needsImprovement, Colors.red),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: Subject Mastery Section
  Widget _buildSubjectMastery(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionCard(
            'Subject Mastery',
            Icons.school,
            const Color(0xFFD62828),
            const Text('No subject data available', style: TextStyle(color: Colors.grey)),
          );
        }

        final Map<String, List<double>> subjectScores = {};
        final Map<String, int> subjectAttempts = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = data['subject']?.toString() ?? 'Unknown';
          final percentage = (data['percentage'] ?? 0).toDouble();

          if (!subjectScores.containsKey(subject)) {
            subjectScores[subject] = [];
            subjectAttempts[subject] = 0;
          }
          subjectScores[subject]!.add(percentage);
          subjectAttempts[subject] = subjectAttempts[subject]! + 1;
        }

        final sortedSubjects = subjectScores.keys.toList()
          ..sort((a, b) {
            final avgA = subjectScores[a]!.reduce((a, b) => a + b) / subjectScores[a]!.length;
            final avgB = subjectScores[b]!.reduce((a, b) => a + b) / subjectScores[b]!.length;
            return avgB.compareTo(avgA);
          });

        return _buildSectionCard(
          'Subject Mastery',
          Icons.school,
          const Color(0xFFD62828),
          Column(
            children: sortedSubjects.map((subject) {
              final scores = subjectScores[subject]!;
              final average = scores.reduce((a, b) => a + b) / scores.length;
              final attempts = subjectAttempts[subject]!;
              final masteryLevel = average >= 80 ? 'Mastered' : average >= 60 ? 'Proficient' : 'Developing';
              final masteryColor = average >= 80 ? Colors.green : average >= 60 ? Colors.orange : Colors.red;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: masteryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: masteryColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            masteryLevel,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: masteryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${average.toStringAsFixed(1)}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: masteryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($attempts attempt${attempts > 1 ? 's' : ''})',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: average / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(masteryColor),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // NEW: BECE Past Questions Performance
  Widget _buildBecePastQuestions(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionCard(
            'BECE Past Questions',
            Icons.history_edu,
            Colors.indigo,
            const Text('No BECE data available', style: TextStyle(color: Colors.grey)),
          );
        }

        // Filter BECE quizzes
        final beceQuizzes = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = (data['subject'] ?? '').toString().toLowerCase();
          final collectionName = (data['collectionName'] ?? '').toString().toLowerCase();
          final quizType = (data['quizType'] ?? '').toString().toLowerCase();
          return quizType.contains('bece') || quizType.contains('past') ||
                 subject.contains('bece') || subject.contains('past') || 
                 collectionName.contains('bece') || collectionName.contains('past');
        }).toList();

        if (beceQuizzes.isEmpty) {
          return _buildSectionCard(
            'BECE Past Questions',
            Icons.history_edu,
            Colors.indigo,
            const Text('No BECE questions attempted yet', style: TextStyle(color: Colors.grey)),
          );
        }

        final scores = beceQuizzes.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['percentage'] ?? 0).toDouble();
        }).toList();

        final avgScore = scores.reduce((a, b) => a + b) / scores.length;
        final totalQuestions = beceQuizzes.fold<int>(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['totalQuestions'] ?? 0) as int);
        });

        // Subject breakdown for BECE
        final Map<String, List<double>> beceSubjects = {};
        for (var doc in beceQuizzes) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = data['subject']?.toString() ?? 'General';
          final percentage = (data['percentage'] ?? 0).toDouble();

          if (!beceSubjects.containsKey(subject)) {
            beceSubjects[subject] = [];
          }
          beceSubjects[subject]!.add(percentage);
        }

        return _buildSectionCard(
          'BECE Past Questions',
          Icons.history_edu,
          Colors.indigo,
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceStat('Average Score', '${avgScore.toStringAsFixed(1)}%', Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceStat('Questions Solved', '$totalQuestions', Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceStat('Quizzes Taken', '${beceQuizzes.length}', Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceStat('Subjects', '${beceSubjects.length}', Colors.orange),
                  ),
                ],
              ),
              if (beceSubjects.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...beceSubjects.entries.map((entry) {
                  final subjectAvg = entry.value.reduce((a, b) => a + b) / entry.value.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black87),
                        ),
                        Text(
                          '${subjectAvg.toStringAsFixed(1)}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subjectAvg >= 60 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  // NEW: Trivia Performance
  Widget _buildTriviaPerformance(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionCard(
            'Trivia Performance',
            Icons.lightbulb,
            Colors.amber,
            const Text('No trivia data available', style: TextStyle(color: Colors.grey)),
          );
        }

        // Filter trivia quizzes
        final triviaQuizzes = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = (data['subject'] ?? '').toString().toLowerCase();
          final collectionName = (data['collectionName'] ?? '').toString().toLowerCase();
          final quizType = (data['quizType'] ?? '').toString().toLowerCase();
          return quizType.contains('trivia') || subject.contains('trivia') || collectionName.contains('trivia');
        }).toList();

        if (triviaQuizzes.isEmpty) {
          return _buildSectionCard(
            'Trivia Performance',
            Icons.lightbulb,
            Colors.amber,
            const Text('No trivia attempted yet', style: TextStyle(color: Colors.grey)),
          );
        }

        final scores = triviaQuizzes.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['percentage'] ?? 0).toDouble();
        }).toList();

        final avgScore = scores.reduce((a, b) => a + b) / scores.length;
        final bestScore = scores.reduce((a, b) => a > b ? a : b);
        final totalQuestions = triviaQuizzes.fold<int>(0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['totalQuestions'] ?? 0) as int);
        });

        // Calculate win rate (>= 70%)
        final wins = scores.where((s) => s >= 70).length;
        final winRate = (wins / scores.length) * 100;

        return _buildSectionCard(
          'Trivia Performance',
          Icons.lightbulb,
          Colors.amber,
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceStat('Average Score', '${avgScore.toStringAsFixed(1)}%', Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceStat('Best Score', '${bestScore.toStringAsFixed(1)}%', Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceStat('Quizzes Played', '${triviaQuizzes.length}', Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceStat('Win Rate', '${winRate.toStringAsFixed(0)}%', Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$totalQuestions Total Questions Answered',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // NEW: Study Time by Subjects
  Widget _buildStudyTimeBySubjects(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildSectionCard(
            'Study Time by Subjects',
            Icons.access_time,
            Colors.teal,
            const Text('No study time data available', style: TextStyle(color: Colors.grey)),
          );
        }

        // Calculate study time per subject (estimate based on questions and timestamps)
        final Map<String, Duration> subjectTime = {};
        final Map<String, int> subjectSessions = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final subject = data['subject']?.toString() ?? 'Unknown';
          final totalQuestions = (data['totalQuestions'] ?? 0) as int;
          
          // Estimate: ~30 seconds per question
          final estimatedMinutes = (totalQuestions * 0.5).round();
          final duration = Duration(minutes: estimatedMinutes);

          if (!subjectTime.containsKey(subject)) {
            subjectTime[subject] = Duration.zero;
            subjectSessions[subject] = 0;
          }
          subjectTime[subject] = subjectTime[subject]! + duration;
          subjectSessions[subject] = subjectSessions[subject]! + 1;
        }

        final totalMinutes = subjectTime.values.fold<int>(0, (sum, duration) => sum + duration.inMinutes);
        final sortedSubjects = subjectTime.keys.toList()
          ..sort((a, b) => subjectTime[b]!.inMinutes.compareTo(subjectTime[a]!.inMinutes));

        return _buildSectionCard(
          'Study Time by Subjects',
          Icons.access_time,
          Colors.teal,
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.withValues(alpha: 0.2), Colors.cyan.withValues(alpha: 0.2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.teal, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${_formatDuration(Duration(minutes: totalMinutes))}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...sortedSubjects.take(10).map((subject) {
                final duration = subjectTime[subject]!;
                final sessions = subjectSessions[subject]!;
                final percentage = (duration.inMinutes / totalMinutes) * 100;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              subject,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$sessions session${sessions > 1 ? 's' : ''} • ${percentage.toStringAsFixed(0)}% of total time',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 6,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // Helper: Format duration
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }

  // Helper: Section card wrapper
  Widget _buildSectionCard(String title, IconData icon, Color color, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ),
    );
  }

  // Helper: Performance stat card
  Widget _buildPerformanceStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Performance distribution
  Widget _buildPerformanceDistribution(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

