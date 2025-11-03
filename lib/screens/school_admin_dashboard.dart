import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  String? _selectedClass;
  final List<String> _availableClasses = [];
  bool _loadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableClasses();
  }

  Future<void> _loadAvailableClasses() async {
    setState(() => _loadingClasses = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final schoolName = userDoc.data()?['school'];
      if (schoolName == null) return;

      // Get all unique classes in the school
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: schoolName)
          .get();

      final classesSet = <String>{};
      for (final doc in studentsSnap.docs) {
        final className = doc.data()['class'];
        if (className != null && className.toString().isNotEmpty) {
          classesSet.add(className.toString());
        }
      }

      setState(() {
        _availableClasses.clear();
        _availableClasses.addAll(classesSet.toList()..sort());
        _loadingClasses = false;
      });
    } catch (e) {
      debugPrint('Error loading classes: $e');
      setState(() => _loadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final adminId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(adminId).get(),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final adminData = adminSnap.data?.data() as Map<String, dynamic>?;
        final schoolName = adminData?['school'];

        if (schoolName == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Complete Your Profile',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please add your school information to view your dashboard',
                    style: GoogleFonts.montserrat(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Fetch school-wide dashboard data
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchSchoolDashboardData(schoolName),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final dashboardData = snap.data ?? {};
            final totalStudents = (dashboardData['totalStudents'] as int?) ?? 0;
            final totalTeachers = (dashboardData['totalTeachers'] as int?) ?? 0;

            if (totalStudents == 0) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No Students Yet',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Students will appear here once they join your school',
                        style: GoogleFonts.montserrat(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final totalXP = (dashboardData['totalXP'] as int?) ?? 0;
            final totalQuestions = (dashboardData['totalQuestions'] as int?) ?? 0;
            final totalSubjects = (dashboardData['totalSubjects'] as int?) ?? 0;
            final totalAccuracy = (dashboardData['totalAccuracy'] as double?) ?? 0;
            final studentsWithAccuracy =
                (dashboardData['studentsWithAccuracy'] as int?) ?? 0;
            final classBreakdown =
                (dashboardData['classBreakdown'] as Map<String, int>?) ?? {};
            final topStudents =
                (dashboardData['topStudents'] as List<Map<String, dynamic>>?) ?? [];
            final subjectPerformance =
                (dashboardData['subjectPerformance'] as Map<String, Map<String, dynamic>>?) ?? {};

            final avgXP = totalStudents > 0 ? (totalXP / totalStudents) : 0;
            final avgAccuracy = studentsWithAccuracy > 0
                ? (totalAccuracy / studentsWithAccuracy)
                : 0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isSmallScreen ? 24 : 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalStudents == 1 ? '1 student' : '$totalStudents students'} • ${totalTeachers == 1 ? '1 teacher' : '$totalTeachers teachers'}',
                              style: GoogleFonts.montserrat(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_loadingClasses && _availableClasses.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClass,
                              hint: Text(
                                'All Classes',
                                style: GoogleFonts.montserrat(fontSize: 14),
                              ),
                              icon: const Icon(Icons.filter_list, size: 20),
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
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Key Metrics Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = isSmallScreen
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 48) / 4;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildModernMetricCard(
                              'Average XP',
                              avgXP.toStringAsFixed(0),
                              Icons.stars_rounded,
                              const Color(0xFFD62828),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildModernMetricCard(
                              'Total Questions',
                              totalQuestions.toString(),
                              Icons.quiz_rounded,
                              const Color(0xFF2196F3),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildModernMetricCard(
                              'Average Accuracy',
                              avgAccuracy > 0
                                  ? '${avgAccuracy.toStringAsFixed(1)}%'
                                  : 'N/A',
                              Icons.trending_up_rounded,
                              const Color(0xFF00C853),
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _buildModernMetricCard(
                              'Total Subjects',
                              totalSubjects.toString(),
                              Icons.library_books_rounded,
                              const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Class Breakdown
                  if (classBreakdown.isNotEmpty) ...[
                    Text(
                      'Class Distribution',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildClassBreakdownCard(classBreakdown, isSmallScreen),
                    const SizedBox(height: 32),
                  ],

                  // Top Students
                  if (topStudents.isNotEmpty) ...[
                    Text(
                      'Top Performers',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTopStudentsCard(topStudents, isSmallScreen),
                    const SizedBox(height: 32),
                  ],

                  // Subject Performance
                  if (subjectPerformance.isNotEmpty) ...[
                    Text(
                      'Subject Performance',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSubjectPerformanceCard(
                        subjectPerformance, isSmallScreen),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchSchoolDashboardData(
      String schoolName) async {
    try {
      // Get all students in the school (optionally filtered by class)
      Query studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: schoolName);

      if (_selectedClass != null) {
        studentsQuery = studentsQuery.where('class', isEqualTo: _selectedClass);
      }

      final studentsSnap = await studentsQuery.get();
      final studentIds = studentsSnap.docs.map((d) => d.id).toList();

      // Get all teachers in the school
      final teachersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('school', isEqualTo: schoolName)
          .get();

      if (studentIds.isEmpty) {
        return {
          'totalStudents': 0,
          'totalTeachers': teachersSnap.size,
        };
      }

      // Calculate metrics from student summaries
      int totalXP = 0;
      int totalQuestions = 0;
      int totalSubjects = 0;
      double totalAccuracy = 0;
      int studentsWithAccuracy = 0;
      Map<String, int> classBreakdown = {};
      List<Map<String, dynamic>> topStudents = [];
      Map<String, Map<String, dynamic>> subjectPerformance = {};

      // Get student summaries in batches (Firestore 'in' limit is 10)
      for (var i = 0; i < studentIds.length; i += 10) {
        final batch = studentIds.skip(i).take(10).toList();
        final summariesSnap = await FirebaseFirestore.instance
            .collection('studentSummaries')
            .where('studentId', whereIn: batch)
            .get();

        for (final doc in summariesSnap.docs) {
          final data = doc.data();
          final xp = (data['xp'] as int?) ?? 0;
          totalXP += xp;
          totalQuestions += (data['questionsAnswered'] as int?) ?? 0;
          totalSubjects += (data['subjectsSolved'] as int?) ?? 0;

          final acc = data['accuracy'];
          if (acc != null && acc > 0) {
            totalAccuracy += (acc is num) ? acc.toDouble() : 0;
            studentsWithAccuracy++;
          }

          // Track for top students
          topStudents.add({
            'studentId': data['studentId'],
            'studentName': data['studentName'] ?? 'Unknown',
            'xp': xp,
            'rank': data['rankName'] ?? 'Learner',
            'class': data['class'] ?? 'N/A',
          });
        }
      }

      // Class breakdown
      for (final doc in studentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final className = data?['class'] ?? 'Unassigned';
        classBreakdown[className] = (classBreakdown[className] ?? 0) + 1;
      }

      // Get subject performance from quizzes (sample)
      if (studentIds.isNotEmpty) {
        final quizzesSnap = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('userId', whereIn: studentIds.take(10).toList())
            .limit(100)
            .get();

        for (final qDoc in quizzesSnap.docs) {
          final qData = qDoc.data();
          final subject =
              (qData['subject'] ?? qData['collectionName'] ?? 'Other')
                  .toString();
          final percentage = (qData['percentage'] as num?) ?? 0;

          if (!subjectPerformance.containsKey(subject)) {
            subjectPerformance[subject] = {
              'total': 0.0,
              'count': 0,
            };
          }
          subjectPerformance[subject]!['total'] =
              (subjectPerformance[subject]!['total'] as double) +
                  percentage.toDouble();
          subjectPerformance[subject]!['count'] =
              (subjectPerformance[subject]!['count'] as int) + 1;
        }
      }

      // Sort top students by XP
      topStudents.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));

      return {
        'totalStudents': studentIds.length,
        'totalTeachers': teachersSnap.size,
        'totalXP': totalXP,
        'totalQuestions': totalQuestions,
        'totalSubjects': totalSubjects,
        'totalAccuracy': totalAccuracy,
        'studentsWithAccuracy': studentsWithAccuracy,
        'classBreakdown': classBreakdown,
        'topStudents': topStudents.take(10).toList(),
        'subjectPerformance': subjectPerformance,
      };
    } catch (e) {
      debugPrint('Error fetching school dashboard data: $e');
      return {};
    }
  }

  Widget _buildModernMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassBreakdownCard(
      Map<String, int> classBreakdown, bool isSmallScreen) {
    final sortedClasses = classBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: sortedClasses.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: entry.value /
                          sortedClasses.first.value.toDouble(),
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2196F3)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${entry.value}',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopStudentsCard(
      List<Map<String, dynamic>> topStudents, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: topStudents.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          final medalColors = [
            Colors.amber,
            Colors.grey.shade400,
            Colors.brown.shade400,
          ];
          final medalColor =
              index < 3 ? medalColors[index] : Colors.grey.shade300;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                      Text(
                        '${student['class']} • ${student['rank']}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${student['xp']} XP',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD62828),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubjectPerformanceCard(
      Map<String, Map<String, dynamic>> subjectPerformance,
      bool isSmallScreen) {
    final sortedSubjects = subjectPerformance.entries.toList()
      ..sort((a, b) {
        final avgA = (a.value['total'] as double) / (a.value['count'] as int);
        final avgB = (b.value['total'] as double) / (b.value['count'] as int);
        return avgB.compareTo(avgA);
      });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: sortedSubjects.map((entry) {
          final subject = entry.key;
          final data = entry.value;
          final avg = (data['total'] as double) / (data['count'] as int);
          final color = avg >= 70
              ? const Color(0xFF00C853)
              : avg >= 50
                  ? const Color(0xFFFF9800)
                  : const Color(0xFFD62828);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    subject,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: avg / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${avg.toStringAsFixed(1)}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
