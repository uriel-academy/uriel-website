import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'student_profile_page.dart';
import '../services/grade_prediction_service.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  String? _selectedClass;
  final List<String> _availableClasses = ['JHS Form 1', 'JHS Form 2', 'JHS Form 3'];
  bool _loadingClasses = false;
  
  // Dashboard data
  Map<String, dynamic> _subjectMastery = {};
  Map<String, double> _timeBySubject = {};
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;
  String? _schoolName;
  
  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _studentsSubscription;
  StreamSubscription<QuerySnapshot>? _quizzesSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _studentsSubscription?.cancel();
    _quizzesSubscription?.cancel();
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

      _setupRealtimeListeners();
    } catch (e) {
      debugPrint('❌ School Admin Dashboard Error: $e');
      setState(() {
        _error = 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeListeners() {
    if (_schoolName == null) return;

    // Listen to students collection
    _studentsSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()
        .listen((snapshot) {
      _loadData();
    });

    // Listen to teachers collection for dynamic updates
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .listen((snapshot) {
      _loadData();
    });

    // Listen to quizzes collection
    _quizzesSubscription = FirebaseFirestore.instance
        .collection('quizzes')
        .snapshots()
        .listen((snapshot) {
      _loadData();
    });
  }

  String _normalizeClassName(String? className) {
    if (className == null) return 'Unknown';
    
    final normalized = className.trim().toLowerCase();
    
    // Map various formats to standard "JHS Form X"
    if (normalized.contains('1') || normalized.contains('one')) {
      return 'JHS Form 1';
    } else if (normalized.contains('2') || normalized.contains('two')) {
      return 'JHS Form 2';
    } else if (normalized.contains('3') || normalized.contains('three')) {
      return 'JHS Form 3';
    }
    
    return className; // Return original if can't normalize
  }

  bool _classMatches(String? studentClass, String? filterClass) {
    if (filterClass == null) return true; // Show all if no filter
    
    final normalizedStudent = _normalizeClassName(studentClass);
    final normalizedFilter = _normalizeClassName(filterClass);
    
    return normalizedStudent == normalizedFilter;
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (_schoolName == null) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      await Future.wait([
        _loadDashboardData(),
        _loadSubjectMasteryData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading school admin data: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load data';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      debugPrint('🔍 Loading dashboard data for school: $_schoolName');
      debugPrint('   Normalized: ${_normalizeSchoolName(_schoolName ?? "")}');
      
      // Get ALL students first, then filter by school name flexibly
      final studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student');

      final studentsSnap = await studentsQuery.get();
      debugPrint('📊 Query returned ${studentsSnap.docs.length} total students');
      
      // Filter by school name flexibly (handles variations)
      final matchingStudents = studentsSnap.docs.where((doc) {
        final studentSchool = doc.data()['school'];
        return _schoolNamesMatch(studentSchool, _schoolName);
      }).toList();
      
      debugPrint('📊 Filtered to ${matchingStudents.length} students matching school');
      
      // Log first few students for debugging
      if (matchingStudents.isNotEmpty) {
        for (var i = 0; i < matchingStudents.length.clamp(0, 3); i++) {
          final data = matchingStudents[i].data();
          debugPrint('   Student ${i + 1}: ${data['name']} - school: "${data['school']}", role: ${data['role']}');
        }
      } else {
        debugPrint('⚠️ No students found matching school="$_schoolName"');
        // Try to find ANY students to debug
        final anyStudents = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .limit(5)
            .get();
        debugPrint('📋 Found ${anyStudents.docs.length} total students in database');
        if (anyStudents.docs.isNotEmpty) {
          debugPrint('   Sample schools: ${anyStudents.docs.map((d) => d.data()['school']).toSet().join(", ")}');
        }
      }
      
      // Filter by class if selected (using normalized matching)
      final students = matchingStudents.where((doc) {
        final studentClass = doc.data()['class'] ?? doc.data()['grade'];
        return _classMatches(studentClass?.toString(), _selectedClass);
      }).toList();
      
      debugPrint('📊 After class filter: ${students.length} students');

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
        final studentName = studentData['name'] ?? studentData['displayName'] ?? 'Unknown';
        final rawClass = studentData['class'] ?? studentData['grade'];
        final studentClass = _normalizeClassName(rawClass?.toString());
        final rank = studentData['currentRank'] ?? 'Learner';

        debugPrint('📊 Student: $studentName, XP: $xp, Class: $studentClass');

        totalXP += xp;

        // Count class breakdown (normalized)
        if (_selectedClass == null) {
          classBreakdown[studentClass] = (classBreakdown[studentClass] ?? 0) + 1;
        }

        // Get quiz count and accuracy from quizzes collection
        final quizzesSnap = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('userId', isEqualTo: studentId)
            .get();

        int correctAnswers = 0;
        int totalQs = 0;

        for (var quiz in quizzesSnap.docs) {
          final quizData = quiz.data();
          correctAnswers += (quizData['correctAnswers'] as num?)?.toInt() ?? 0;
          totalQs += (quizData['totalQuestions'] as num?)?.toInt() ?? 0;
        }

        totalQuestions += totalQs;

        allStudents.add({
          'studentId': studentId,
          'studentName': studentName,
          'xp': xp,
          'rank': rank,
          'class': studentClass,
          'questionsAnswered': totalQs,
          'accuracy': totalQs > 0 ? (correctAnswers / totalQs) * 100 : 0,
        });
      }

      // Sort all students alphabetically by name first
      allStudents.sort((a, b) {
        final nameA = (a['studentName'] ?? '').toString().toLowerCase();
        final nameB = (b['studentName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });
      
      // Create a copy for top students and sort by XP
      final topStudentsList = List<Map<String, dynamic>>.from(allStudents);
      topStudentsList.sort((a, b) => (b['xp'] as int).compareTo(a['xp'] as int));
      final topStudents = topStudentsList.take(5).toList();

      // Calculate average accuracy across all students who have answered questions
      double avgAccuracy = 0;
      int studentsWithQuizzes = allStudents.where((s) => (s['questionsAnswered'] as int) > 0).length;
      if (studentsWithQuizzes > 0) {
        double totalAccuracySum = allStudents
            .where((s) => (s['questionsAnswered'] as int) > 0)
            .fold(0.0, (sum, s) => sum + (s['accuracy'] as double));
        avgAccuracy = totalAccuracySum / studentsWithQuizzes;
      }      // Get teacher count with flexible school matching
      final allTeachersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      
      // Filter teachers by school name flexibly
      final teachersInSchool = allTeachersSnap.docs.where((doc) {
        final teacherSchool = doc.data()['school'];
        return _schoolNamesMatch(teacherSchool, _schoolName);
      }).toList();
      
      debugPrint('📊 Found ${teachersInSchool.length} teachers in school');

      if (mounted) {
        setState(() {
          _dashboardData = {
            'totalStudents': students.length,
            'totalTeachers': teachersInSchool.length,
            'totalXP': totalXP,
            'totalQuestions': totalQuestions,
            'avgAccuracy': avgAccuracy,
            'studentsWithQuizzes': studentsWithQuizzes,
            'classBreakdown': classBreakdown,
            'topStudents': topStudents,
            'allStudents': allStudents,
          };
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading dashboard data: $e');
    }
  }

  Future<void> _loadSubjectMasteryData() async {
    try {
      debugPrint('🔍 Loading subject mastery data for school: $_schoolName');
      
      // Get all students, then filter by school flexibly
      final studentsQuery = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student');

      final studentsSnap = await studentsQuery.get();
      
      // Filter by school name flexibly
      final matchingStudents = studentsSnap.docs.where((doc) {
        final studentSchool = doc.data()['school'];
        return _schoolNamesMatch(studentSchool, _schoolName);
      }).toList();
      
      // Filter by class if selected (using normalized matching)
      final students = matchingStudents.where((doc) {
        final studentClass = doc.data()['class'] ?? doc.data()['grade'];
        return _classMatches(studentClass?.toString(), _selectedClass);
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

      // Calculate averages for subjects that have MCQ questions in database
      Map<String, dynamic> subjectMastery = {};
      final beceSubjects = [
        'English',
        'Mathematics',
        'Science',
        'Social Studies',
        'RME',
        'ICT',
        'French',
        'Ga',
        'Asante Twi',
        'Career Technology',
        'Creative Arts',
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

      if (mounted) {
        setState(() {
          _subjectMastery = subjectMastery;
          _timeBySubject = timeData;
        });
      }

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
    if (normalized.contains('ict') || normalized.contains('information')) return 'ICT';
    if (normalized.contains('french')) return 'French';
    if (normalized.contains('ga') && !normalized.contains('twi')) return 'Ga';
    if (normalized.contains('twi') || normalized.contains('asante')) return 'Asante Twi';
    if (normalized.contains('career') || normalized.contains('technology')) return 'Career Technology';
    if (normalized.contains('creative') || normalized.contains('arts')) return 'Creative Arts';
    
    return subject;
  }

  String _normalizeSchoolName(String schoolName) {
    // Remove common variations and normalize
    return schoolName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')  // normalize whitespace
        .replaceAll(' school', '')
        .replaceAll(' academy', '')
        .replaceAll(' international', '')
        .trim();
  }

  bool _schoolNamesMatch(String? school1, String? school2) {
    if (school1 == null || school2 == null) return false;
    if (school1 == school2) return true;  // exact match
    
    final normalized1 = _normalizeSchoolName(school1);
    final normalized2 = _normalizeSchoolName(school2);
    
    return normalized1 == normalized2;
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

    if (_dashboardData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Loading Dashboard...',
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

    // Build header with filter (always visible)
    final header = Padding(
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
          // Class filter dropdown (always visible)
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
                  setState(() {
                    _selectedClass = value;
                    _isLoading = true; // Show loading during filter
                  });
                  _loadData();
                },
              ),
            ),
          ),
        ],
      ),
    );

    // Empty state with filter still visible
    if (totalStudents == 0) {
      final message = _selectedClass != null
          ? 'No students found in $_selectedClass'
          : 'No Students Yet';
      final subtitle = _selectedClass != null
          ? 'Try selecting a different class or "All Classes"'
          : 'Students will appear here once they join your school';
          
      return Column(
        children: [
          header,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        // Dashboard Content
        Expanded(
          child: _buildDashboardContent(isSmallScreen),
        ),
      ],
    );
  }

  Widget _buildDashboardContent(bool isSmallScreen) {
    final totalStudents = (_dashboardData?['totalStudents'] as int?) ?? 0;
    final totalXP = (_dashboardData?['totalXP'] as int?) ?? 0;
    final totalQuestions = (_dashboardData?['totalQuestions'] as int?) ?? 0;
    final avgAccuracy = (_dashboardData?['avgAccuracy'] as double?) ?? 0;
    final avgXP = totalStudents > 0 ? (totalXP / totalStudents).toDouble() : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Overview Card
          _buildClassOverviewCard(avgXP, totalQuestions, avgAccuracy, isSmallScreen),
          
          const SizedBox(height: 24),

          // Subject Mastery Card (Subjects with MCQ Questions)
          Text(
            'Subject Mastery',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSubjectMasteryCard(isSmallScreen),
          
          const SizedBox(height: 24),

          // School-Wide Grade Predictions
          Text(
            'School-Wide Grade Predictions',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSchoolGradePredictionAnalytics(isSmallScreen),
          
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
          
          const SizedBox(height: 24),

          // Messages & Notifications Card
          Text(
            'Messages & Notifications',
            style: GoogleFonts.playfairDisplay(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMessagesNotificationsCardForSchoolAdmin(isSmallScreen),
        ],
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
      'RME', 'ICT', 'French', 'Ga', 'Asante Twi',
      'Career Technology', 'Creative Arts'
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
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  // Messages & Notifications card - self-contained
  Widget _buildMessagesNotificationsCardForSchoolAdmin(bool isSmallScreen) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final allNotifications = snapshot.data!.docs;
        final unreadCount = allNotifications.where((doc) => !(doc.data() as Map<String, dynamic>)['read'] as bool? ?? false).length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001F3F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF001F3F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Messages & Notifications',
                      style: GoogleFonts.montserrat(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF001F3F),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (allNotifications.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No notifications yet',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...allNotifications.take(5).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isRead = data['read'] as bool? ?? false;
                  final title = data['title'] as String? ?? 'Notification';
                  final message = data['message'] as String? ?? '';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final senderRole = data['senderRole'] as String? ?? 'unknown';

                  String timeAgo = 'Just now';
                  if (timestamp != null) {
                    final now = DateTime.now();
                    final messageTime = timestamp.toDate();
                    final difference = now.difference(messageTime);

                    if (difference.inDays > 0) {
                      timeAgo = '${difference.inDays}d ago';
                    } else if (difference.inHours > 0) {
                      timeAgo = '${difference.inHours}h ago';
                    } else if (difference.inMinutes > 0) {
                      timeAgo = '${difference.inMinutes}m ago';
                    }
                  }

                  Color senderColor;
                  IconData senderIcon;
                  switch (senderRole) {
                    case 'teacher':
                      senderColor = Colors.blue;
                      senderIcon = Icons.school;
                      break;
                    case 'school_admin':
                      senderColor = Colors.purple;
                      senderIcon = Icons.admin_panel_settings;
                      break;
                    case 'super_admin':
                      senderColor = Colors.orange;
                      senderIcon = Icons.verified_user;
                      break;
                    default:
                      senderColor = Colors.grey;
                      senderIcon = Icons.person;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : const Color(0xFF001F3F).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRead ? Colors.grey[200]! : const Color(0xFF001F3F).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          // Mark as read
                          FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'read': true});
                          // Show detail (you can implement this later)
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: senderColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(senderIcon, color: senderColor, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                        color: const Color(0xFF001F3F),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      timeAgo,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSchoolGradePredictionAnalytics(bool isSmallScreen) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<List<String>>(
      future: _getSchoolStudentIds(_selectedClass),
      builder: (context, snapshot) {
        debugPrint('🔍 School Admin Analytics - ConnectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, data length: ${snapshot.data?.length ?? 0}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Students Found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedClass != null
                      ? 'No students in $_selectedClass yet'
                      : 'Students will appear here once they join your school',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final studentIds = snapshot.data!;

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
              // Info Box: AI Model Explanation
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF6366F1),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI-Powered Grade Predictions',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedClass != null
                                ? 'This shows how many students in $_selectedClass are predicted to achieve each BECE grade (1-9) based on their quiz performance. Our AI model requires each student to complete at least 20 quizzes with 40% topic diversity to make reliable predictions.'
                                : 'This shows how many students in your school are predicted to achieve each BECE grade (1-9) based on their quiz performance. Our AI model requires each student to complete at least 20 quizzes with 40% topic diversity to make reliable predictions.',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.analytics,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedClass != null
                              ? '$_selectedClass Grade Predictions'
                              : 'School-Wide Grade Predictions',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        Text(
                          '${studentIds.length} students • BECE predictions',
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
              const SizedBox(height: 20),
              _buildSchoolGradeDistributionView(studentIds, isSmallScreen),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _getSchoolStudentIds(String? classFilter) async {
    try {
      // Get current admin's school
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) return [];

      final adminData = adminDoc.data() as Map<String, dynamic>;
      final schoolName = adminData['schoolName'] as String?;

      if (schoolName == null) return [];

      // Build query for students in this school
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('schoolName', isEqualTo: schoolName);

      // Apply class filter if specified
      if (classFilter != null) {
        query = query.where('class', isEqualTo: classFilter);
      }

      final studentsQuery = await query.limit(500).get(); // Increased limit for school-wide

      final studentIds = studentsQuery.docs.map((doc) => doc.id).toList();
      debugPrint('🔍 School Admin: Found ${studentIds.length} students for school: $schoolName, class: $classFilter');
      return studentIds;
    } catch (e) {
      debugPrint('❌ Error fetching school students: $e');
      return [];
    }
  }

  Widget _buildSchoolGradeDistributionView(
    List<String> studentIds,
    bool isSmallScreen,
  ) {
    final subjects = [
      'Mathematics',
      'English Language',
      'Integrated Science',
      'Social Studies',
      'RME',
      'ICT',
      'Ga',
      'Asante Twi',
      'French',
      'Creative Arts',
      'Career Technology',
    ];

    return FutureBuilder<Map<String, Map<int, List<String>>>>(
      future: GradePredictionService().getGradeDistribution(
        studentIds: studentIds,
        subjects: subjects,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'No prediction data available',
              style: GoogleFonts.montserrat(color: Colors.grey[600]),
            ),
          );
        }

        final distribution = snapshot.data!;

        return Column(
          children: [
            for (final subject in subjects)
              if (distribution[subject] != null)
                _buildSchoolSubjectGradeCard(
                  subject,
                  distribution[subject]!,
                  studentIds.length,
                  isSmallScreen,
                ),
          ],
        );
      },
    );
  }

  Widget _buildSchoolSubjectGradeCard(
    String subject,
    Map<int, List<String>> gradeDistribution,
    int totalStudents,
    bool isSmallScreen,
  ) {
    final studentsWithPredictions = gradeDistribution.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    if (studentsWithPredictions == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$studentsWithPredictions/$totalStudents students',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int grade = 1; grade <= 9; grade++)
                if (gradeDistribution[grade]!.isNotEmpty)
                  _buildSchoolGradeChip(
                    grade,
                    gradeDistribution[grade]!.length,
                    _getSchoolGradeColor(grade),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolGradeChip(int grade, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Grade $grade',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSchoolGradeColor(int grade) {
    if (grade <= 3) return Colors.green;
    if (grade <= 6) return Colors.orange;
    return Colors.red;
  }
}


