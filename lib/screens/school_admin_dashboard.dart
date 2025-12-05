import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'student_profile_page.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> with SingleTickerProviderStateMixin {
  String? _selectedClass;
  final List<String> _availableClasses = [];
  bool _loadingClasses = true;
  
  // Tab controller for Dashboard/Students view
  late TabController _tabController;
  
  // Dashboard data
  Map<String, dynamic> _subjectMastery = {};
  Map<String, double> _timeBySubject = {};
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;
  String? _schoolName;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();

      final adminData = adminSnap.data();
      _schoolName = adminData?['school'];

      if (_schoolName == null) {
        setState(() {
          _error = 'Complete your profile to view dashboard';
          _isLoading = false;
        });
        return;
      }

      await _loadAvailableClasses();
      await _loadData();
    } catch (e) {
      debugPrint('❌ School Admin Dashboard Error: $e');
      setState(() {
        _error = 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (_schoolName == null) return;

    try {
      await Future.wait([
        _loadDashboardData(),
        _loadSubjectMasteryData(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading school admin data: $e');
      setState(() {
        _error = 'Failed to load data';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: _schoolName);

      final studentsSnap = await studentsQuery.get();
      
      // Filter by class if selected
      final students = studentsSnap.docs.where((doc) {
        if (_selectedClass == null) return true;
        final studentClass = doc.data()['class'] ?? doc.data()['grade'];
        return studentClass == _selectedClass;
      }).toList();

      int totalXP = 0;
      int totalQuestions = 0;
      double totalAccuracy = 0;
      int studentsWithAccuracy = 0;
      Map<String, int> classBreakdown = {};
      List<Map<String, dynamic>> allStudents = [];

      for (var studentDoc in students) {
        final studentData = studentDoc.data();
        final studentId = studentDoc.id;
        final xp = (studentData['xp'] as num?)?.toInt() ?? 0;
        final studentName = studentData['name'] ?? 'Unknown';
        final studentClass = studentData['class'] ?? studentData['grade'] ?? 'N/A';
        final rank = studentData['currentRank'] ?? 'Learner';

        totalXP += xp;

        // Count class breakdown
        if (_selectedClass == null) {
          classBreakdown[studentClass] = (classBreakdown[studentClass] ?? 0) + 1;
        }

        // Get quiz data for this student
        final quizzesSnap = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('userId', isEqualTo: studentId)
            .get();

        if (quizzesSnap.docs.isNotEmpty) {
          int correctAnswers = 0;
          int totalQs = 0;

          for (var quiz in quizzesSnap.docs) {
            final quizData = quiz.data();
            correctAnswers += (quizData['correctAnswers'] as num?)?.toInt() ?? 0;
            totalQs += (quizData['totalQuestions'] as num?)?.toInt() ?? 0;
          }

          totalQuestions += totalQs;
          
          if (totalQs > 0) {
            final accuracy = (correctAnswers / totalQs) * 100;
            totalAccuracy += accuracy;
            studentsWithAccuracy++;
          }

          allStudents.add({
            'studentId': studentId,
            'studentName': studentName,
            'xp': xp,
            'rank': rank,
            'class': studentClass,
            'questionsAnswered': totalQs,
            'accuracy': totalQs > 0 ? (correctAnswers / totalQs) * 100 : 0,
          });
        } else {
          allStudents.add({
            'studentId': studentId,
            'studentName': studentName,
            'xp': xp,
            'rank': rank,
            'class': studentClass,
            'questionsAnswered': 0,
            'accuracy': 0,
          });
        }
      }

      // Sort students by XP
      allStudents.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
      final topStudents = allStudents.take(10).toList();

      // Get teacher count
      final teachersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('school', isEqualTo: _schoolName)
          .get();

      setState(() {
        _dashboardData = {
          'totalStudents': students.length,
          'totalTeachers': teachersSnap.docs.length,
          'totalXP': totalXP,
          'totalQuestions': totalQuestions,
          'totalAccuracy': totalAccuracy,
          'studentsWithAccuracy': studentsWithAccuracy,
          'classBreakdown': classBreakdown,
          'topStudents': topStudents,
          'allStudents': allStudents,
        };
      });
    } catch (e) {
      debugPrint('❌ Error loading dashboard data: $e');
    }
  }

  Future<void> _loadSubjectMasteryData() async {
    try {
      debugPrint('🔍 Loading subject mastery data for school: $_schoolName');
      
      // Get all students in the school
      final studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: _schoolName);

      final studentsSnap = await studentsQuery.get();
      
      // Filter by class if selected
      final students = studentsSnap.docs.where((doc) {
        if (_selectedClass == null) return true;
        final studentClass = doc.data()['class'] ?? doc.data()['grade'];
        return studentClass == _selectedClass;
      }).toList();

      debugPrint('📊 Found ${students.length} students in school');

      Map<String, Map<String, dynamic>> subjectData = {};
      Map<String, double> timeData = {};

      for (var studentDoc in students) {
        final studentId = studentDoc.id;
        
        final quizzesSnap = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('userId', isEqualTo: studentId)
            .get();

        for (var quizDoc in quizzesSnap.docs) {
          final quizData = quizDoc.data();
          final subject = _normalizeSubject(quizData['subject'] as String? ?? 'Unknown');
          final score = (quizData['percentage'] as num?)?.toDouble() ?? 0.0;
          final questions = (quizData['totalQuestions'] as num?)?.toInt() ?? 0;

          if (!subjectData.containsKey(subject)) {
            subjectData[subject] = {'total': 0.0, 'count': 0};
          }
          subjectData[subject]!['total'] = (subjectData[subject]!['total'] as double) + score;
          subjectData[subject]!['count'] = (subjectData[subject]!['count'] as int) + 1;

          // Calculate time (2 minutes per question)
          timeData[subject] = (timeData[subject] ?? 0) + (questions * 2);
        }
      }

      // Calculate averages and ensure all 11 BECE subjects are present
      Map<String, dynamic> subjectMastery = {};
      final beceSubjects = [
        'English',
        'Mathematics',
        'Science',
        'Social Studies',
        'RME',
        'French',
        'ICT',
        'BDT',
        'Home Economics',
        'Visual Arts',
        'Ga',
        'Asante Twi',
      ];

      for (var subject in beceSubjects) {
        if (subjectData.containsKey(subject) && subjectData[subject]!['count'] > 0) {
          final avg = (subjectData[subject]!['total'] as double) / (subjectData[subject]!['count'] as int);
          subjectMastery[subject] = {
            'average': avg,
            'count': subjectData[subject]!['count'],
          };
        } else {
          subjectMastery[subject] = {
            'average': 0.0,
            'count': 0,
          };
        }
      }

      setState(() {
        _subjectMastery = subjectMastery;
        _timeBySubject = timeData;
      });

      debugPrint('✅ Subject mastery loaded: ${subjectMastery.length} subjects');
    } catch (e) {
      debugPrint('❌ Error loading subject mastery: $e');
    }
  }

  String _normalizeSubject(String subject) {
    final normalized = subject.trim().toLowerCase();
    
    if (normalized.contains('english')) return 'English';
    if (normalized.contains('math')) return 'Mathematics';
    if (normalized.contains('science')) return 'Science';
    if (normalized.contains('social')) return 'Social Studies';
    if (normalized.contains('rme') || normalized.contains('religious')) return 'RME';
    if (normalized.contains('french')) return 'French';
    if (normalized.contains('ict') || normalized.contains('information')) return 'ICT';
    if (normalized.contains('bdt') || normalized.contains('basic design')) return 'BDT';
    if (normalized.contains('home') || normalized.contains('economics')) return 'Home Economics';
    if (normalized.contains('visual') || normalized.contains('arts')) return 'Visual Arts';
    if (normalized.contains('ga') && !normalized.contains('twi')) return 'Ga';
    if (normalized.contains('twi') || normalized.contains('asante')) return 'Asante Twi';
    
    return subject;
  }


  Future<void> _loadAvailableClasses() async {
    try {
      if (_schoolName == null) return;

      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('school', isEqualTo: _schoolName)
          .get();

      final classesSet = <String>{};
      for (final doc in studentsSnap.docs) {
        final className = doc.data()['class'] ?? doc.data()['grade'];
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final totalStudents = (_dashboardData?['totalStudents'] as int?) ?? 0;

    if (totalStudents == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
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

    return Column(
      children: [
        // Header with school name and filter
        Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _schoolName ?? 'School Dashboard',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isSmallScreen ? 24 : 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalStudents ${totalStudents == 1 ? 'student' : 'students'} • ${(_dashboardData?['totalTeachers'] as int?) ?? 0} ${((_dashboardData?['totalTeachers'] as int?) ?? 0) == 1 ? 'teacher' : 'teachers'}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        _loadData();
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: const Color(0xFF2196F3),
            unselectedLabelColor: Colors.grey[600],
            labelStyle: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Students'),
            ],
          ),
        ),
        
        const SizedBox(height: 24),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(isSmallScreen),
              _buildStudentsTab(isSmallScreen),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab(bool isSmallScreen) {
    final totalStudents = (_dashboardData?['totalStudents'] as int?) ?? 0;
    final totalXP = (_dashboardData?['totalXP'] as int?) ?? 0;
    final totalQuestions = (_dashboardData?['totalQuestions'] as int?) ?? 0;
    final totalAccuracy = (_dashboardData?['totalAccuracy'] as double?) ?? 0;
    final studentsWithAccuracy = (_dashboardData?['studentsWithAccuracy'] as int?) ?? 0;
    final avgXP = totalStudents > 0 ? (totalXP / totalStudents).toDouble() : 0.0;
    final avgAccuracy = studentsWithAccuracy > 0 ? (totalAccuracy / studentsWithAccuracy).toDouble() : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Overview Card
          _buildClassOverviewCard(avgXP, totalQuestions, avgAccuracy, isSmallScreen),
          
          const SizedBox(height: 24),

          // Subject Mastery Card (11 BECE Subjects)
          Text(
            'Subject Mastery (11 BECE Subjects)',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSubjectMasteryCard(isSmallScreen),
          
          const SizedBox(height: 24),

          // Time Spent by Subject Card
          Text(
            'Time Spent by Subject',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimeSpentCard(isSmallScreen),
          
          const SizedBox(height: 24),

          // Students at Risk
          Text(
            'Students at Risk',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStudentsAtRiskCard(isSmallScreen),
          
          const SizedBox(height: 24),

          // Distribution Charts Row
          Row(
            children: [
              Expanded(child: _buildPerformanceDistributionCard(isSmallScreen)),
              if (!isSmallScreen) const SizedBox(width: 16),
              if (!isSmallScreen) Expanded(child: _buildXPDistributionCard(isSmallScreen)),
            ],
          ),
          
          if (isSmallScreen) ...[
            const SizedBox(height: 16),
            _buildXPDistributionCard(isSmallScreen),
          ],
          
          const SizedBox(height: 24),

          // Top Students
          Text(
            'Top Performers',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTopStudentsCard(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildStudentsTab(bool isSmallScreen) {
    final allStudents = (_dashboardData?['allStudents'] as List<Map<String, dynamic>>?) ?? [];
    
    if (allStudents.isEmpty) {
      return Center(
        child: Text(
          'No students found',
          style: GoogleFonts.montserrat(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      itemCount: allStudents.length,
      itemBuilder: (context, index) {
        final student = allStudents[index];
        return _buildStudentCard(student, isSmallScreen);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isSmallScreen) {
    final xp = student['xp'] as int;
    final questionsAnswered = student['questionsAnswered'] as int;
    final accuracy = student['accuracy'] as double;
    
    Color accuracyColor = const Color(0xFF00C853);
    if (accuracy < 50) {
      accuracyColor = const Color(0xFFD62828);
    } else if (accuracy < 70) {
      accuracyColor = const Color(0xFFFF9800);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentProfilePage(testUserId: student['studentId']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2196F3).withValues(alpha: 0.8),
                          const Color(0xFF1976D2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (student['studentName'] as String).substring(0, 1).toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and class
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['studentName'],
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              student['class'],
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              ' • ',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              student['rank'],
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: const Color(0xFF2196F3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // XP Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFD62828).withValues(alpha: 0.1),
                          const Color(0xFFD62828).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD62828).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 16, color: Color(0xFFD62828)),
                        const SizedBox(width: 4),
                        Text(
                          '$xp XP',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.quiz_outlined,
                      'Questions',
                      '$questionsAnswered',
                      const Color(0xFF2196F3),
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.trending_up_rounded,
                      'Accuracy',
                      questionsAnswered > 0 ? '${accuracy.toStringAsFixed(1)}%' : 'N/A',
                      accuracyColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassOverviewCard(double avgXP, int totalQuestions, double avgAccuracy, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Overview',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = isSmallScreen ? constraints.maxWidth : (constraints.maxWidth - 32) / 3;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricItem(
                      'Average XP',
                      avgXP.toStringAsFixed(0),
                      Icons.stars_rounded,
                      const Color(0xFF1A1E3F),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricItem(
                      'Total Questions',
                      totalQuestions.toString(),
                      Icons.quiz_rounded,
                      const Color(0xFF2196F3),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildMetricItem(
                      'Average Accuracy',
                      avgAccuracy > 0 ? '${avgAccuracy.toStringAsFixed(1)}%' : 'N/A',
                      Icons.trending_up_rounded,
                      const Color(0xFF00C853),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectMasteryCard(bool isSmallScreen) {
    final beceSubjects = [
      'English', 'Mathematics', 'Science', 'Social Studies',
      'RME', 'French', 'ICT', 'BDT',
      'Home Economics', 'Visual Arts', 'Ga', 'Asante Twi'
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _subjectMastery.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No quiz data available yet. Students need to take quizzes.',
                  style: GoogleFonts.montserrat(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: beceSubjects.map((subject) {
                final data = _subjectMastery[subject];
                
                if (data == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              subject,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              'No data',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final avg = data['average'] as double;
                final count = data['count'] as int;

                Color scoreColor;
                if (avg >= 80) {
                  scoreColor = const Color(0xFF00C853);
                } else if (avg >= 60) {
                  scoreColor = const Color(0xFF2196F3);
                } else if (avg >= 40) {
                  scoreColor = const Color(0xFFFFA726);
                } else {
                  scoreColor = const Color(0xFFE53935);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
                              ),
                            ),
                          ),
                          Text(
                            '${avg.toStringAsFixed(1)}%',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: avg / 100,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count student${count != 1 ? 's' : ''}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTimeSpentCard(bool isSmallScreen) {
    if (_timeBySubject.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No time data available yet. Students need to take quizzes.',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final sortedEntries = _timeBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalTime = _timeBySubject.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
        children: sortedEntries.map((entry) {
          final subject = entry.key;
          final minutes = entry.value;
          final percentage = totalTime > 0 ? (minutes / totalTime * 100) : 0.0;

          final hours = (minutes / 60).floor();
          final mins = (minutes % 60).round();
          final timeText = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
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
                        ),
                      ),
                    ),
                    Text(
                      timeText,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentage.toStringAsFixed(1)}% of total',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentsAtRiskCard(bool isSmallScreen) {
    final allStudents = (_dashboardData?['allStudents'] as List<Map<String, dynamic>>?) ?? [];
    final atRiskStudents = allStudents.where((s) {
      final accuracy = s['accuracy'] as double;
      return accuracy > 0 && accuracy < 50;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62828).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD62828), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students at Risk',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${atRiskStudents.length} student${atRiskStudents.length != 1 ? 's' : ''} below 50% accuracy',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (atRiskStudents.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Great! All students are performing well.',
                      style: GoogleFonts.montserrat(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ...atRiskStudents.take(5).map((student) {
              final name = student['studentName'];
              final accuracy = student['accuracy'] as double;
              final questions = student['questionsAnswered'] as int;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
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
                            name,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$questions questions • ${accuracy.toStringAsFixed(1)}% accuracy',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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
  }

  Widget _buildPerformanceDistributionCard(bool isSmallScreen) {
    final allStudents = (_dashboardData?['allStudents'] as List<Map<String, dynamic>>?) ?? [];
    
    final ranges = [
      {'label': '90-100%', 'min': 90, 'max': 100, 'color': const Color(0xFF00C853)},
      {'label': '80-89%', 'min': 80, 'max': 89, 'color': const Color(0xFF4CAF50)},
      {'label': '70-79%', 'min': 70, 'max': 79, 'color': const Color(0xFF2196F3)},
      {'label': '60-69%', 'min': 60, 'max': 69, 'color': const Color(0xFFFFA726)},
      {'label': 'Below 60%', 'min': 0, 'max': 59, 'color': const Color(0xFFE53935)},
    ];

    final distribution = ranges.map((range) {
      final count = allStudents.where((s) {
        final accuracy = s['accuracy'] as double;
        return accuracy >= (range['min'] as int) && accuracy <= (range['max'] as int);
      }).length;
      return {...range, 'count': count};
    }).toList();

    final maxCount = distribution.map((d) => d['count'] as int).fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Distribution',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...distribution.map((range) {
            final count = range['count'] as int;
            final percentage = allStudents.isNotEmpty ? (count / allStudents.length * 100) : 0.0;
            final barWidth = maxCount > 0 ? (count / maxCount) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        range['label'] as String,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$count (${percentage.toStringAsFixed(0)}%)',
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
                      value: barWidth,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(range['color'] as Color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildXPDistributionCard(bool isSmallScreen) {
    final topStudents = (_dashboardData?['topStudents'] as List<Map<String, dynamic>>?) ?? [];
    final maxXP = topStudents.isNotEmpty ? (topStudents.first['xp'] as int) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XP Distribution',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (topStudents.isEmpty) ...[
            Center(
              child: Text(
                'No XP data available',
                style: GoogleFonts.montserrat(color: Colors.grey[600]),
              ),
            ),
          ] else ...[
            ...topStudents.asMap().entries.map((entry) {
              final index = entry.key;
              final student = entry.value;
              final name = student['studentName'];
              final xp = student['xp'] as int;
              final barWidth = maxXP > 0 ? (xp / maxXP) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? const Color(0xFFFFA726) : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2196F3).withValues(alpha: 0.8),
                            const Color(0xFF1976D2),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
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
                            name,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: barWidth,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A1E3F)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$xp',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
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
  }

  Widget _buildTopStudentsCard(bool isSmallScreen) {
    final topStudents = (_dashboardData?['topStudents'] as List<Map<String, dynamic>>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topStudents.isEmpty) ...[
            Center(
              child: Text(
                'No data available',
                style: GoogleFonts.montserrat(color: Colors.grey[600]),
              ),
            ),
          ] else ...[
            ...topStudents.asMap().entries.map((entry) {
              final index = entry.key;
              final student = entry.value;
              final medalColors = [
                Colors.amber,
                Colors.grey.shade400,
                Colors.brown.shade400,
              ];
              final medalColor = index < 3 ? medalColors[index] : Colors.grey.shade300;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentProfilePage(testUserId: student['studentId']),
                      ),
                    );
                  },
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
                              student['studentName'],
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
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

