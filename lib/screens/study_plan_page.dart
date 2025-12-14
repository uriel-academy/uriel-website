import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({Key? key}) : super(key: key);

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Simplified onboarding state
  int _currentStep = 0;
  bool _hasExistingPlan = false;
  bool _isLoadingPlan = false;
  bool _isGeneratingPlan = false;
  
  // Step 1: Exam Focus (BECE or End-of-Term)
  String _examType = 'BECE 2026'; // BECE 2026, End-of-Term 1, End-of-Term 2, End-of-Term 3
  DateTime? _examDate;
  final _examDateController = TextEditingController();
  
  // Step 2: Subject Selection
  final List<Map<String, dynamic>> _selectedSubjects = [];
  
  final List<Map<String, dynamic>> _beceSubjects = [
    {'name': 'Mathematics', 'icon': Icons.calculate, 'color': const Color(0xFF0071E3)},
    {'name': 'English Language', 'icon': Icons.book, 'color': const Color(0xFF34C759)},
    {'name': 'Integrated Science', 'icon': Icons.science, 'color': const Color(0xFF5856D6)},
    {'name': 'Social Studies', 'icon': Icons.public, 'color': const Color(0xFFFF9500)},
    {'name': 'Ga', 'icon': Icons.language, 'color': const Color(0xFF667EEA)},
    {'name': 'Asante Twi', 'icon': Icons.translate, 'color': const Color(0xFFFF6482)},
    {'name': 'French', 'icon': Icons.flag, 'color': const Color(0xFF764BA2)},
    {'name': 'ICT', 'icon': Icons.computer, 'color': const Color(0xFF00C7BE)},
    {'name': 'RME', 'icon': Icons.auto_stories, 'color': const Color(0xFFBF5AF2)},
    {'name': 'Creative Arts', 'icon': Icons.palette, 'color': const Color(0xFFFF2D55)},
  ];
  
  // Preferences (with smart defaults)
  int _weeklyHours = 15;
  String _preferredTime = 'Afternoon';
  
  // Generated plan
  Map<String, dynamic>? _generatedPlan;
  
  // Progress tracking
  Map<String, Map<int, bool>> _sessionCompletions = {};
  final int _currentWeek = 1;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _checkExistingPlan();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _examDateController.dispose();
    super.dispose();
  }
  
  Future<void> _checkExistingPlan() async {
    setState(() => _isLoadingPlan = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          _hasExistingPlan = true;
          _generatedPlan = data['studyPlan'];
          // Load tracking data
          final tracking = data['tracking'] as Map<String, dynamic>?;
          if (tracking != null) {
            _sessionCompletions = tracking.map((day, sessions) =>
              MapEntry(day, Map<int, bool>.from(sessions as Map))
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking existing plan: $e');
    } finally {
      setState(() => _isLoadingPlan = false);
    }
  }
  
  Future<void> _generateStudyPlan() async {
    setState(() => _isGeneratingPlan = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Generate algorithm-based daily study schedule
      final dailySchedule = _createDailySchedule();
      
      final planData = {
        'examType': _examType,
        'examDate': _examDate?.toIso8601String(),
        'subjects': _beceSubjects.map((s) => s['name']).toList(), // All BECE subjects
        'dailySchedule': dailySchedule,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      final studyPlan = {
        'examType': _examType,
        'subjects': _beceSubjects,
        'dailySchedule': dailySchedule,
      };
      
      setState(() {
        _generatedPlan = studyPlan;
        _hasExistingPlan = true;
        _sessionCompletions = {};
      });
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current')
          .set({
        ...planData,
        'studyPlan': studyPlan,
        'tracking': {},
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Your personalized study plan is ready!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating study plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating plan: $e'),
            backgroundColor: const Color(0xFFD62828),
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingPlan = false);
    }
  }
  
  Future<void> _toggleSessionCompletion(String day, int sessionIndex) async {
    setState(() {
      if (!_sessionCompletions.containsKey(day)) {
        _sessionCompletions[day] = {};
      }
      final currentStatus = _sessionCompletions[day]![sessionIndex] ?? false;
      _sessionCompletions[day]![sessionIndex] = !currentStatus;
    });
    
    // Save to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('study_plan')
            .doc('current')
            .update({
          'tracking': _sessionCompletions,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }
  
  Future<void> _createNewPlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Plan?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          'This will replace your current study plan. Your progress will be archived.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3)),
            child: Text('Create New', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _hasExistingPlan = false;
        _generatedPlan = null;
        _currentStep = 0;
        _selectedSubjects.clear();
        _sessionCompletions = {};
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    if (_isLoadingPlan) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Wrap everything in SafeArea for iOS Safari bars
    return SafeArea(
      child: _hasExistingPlan && _generatedPlan != null
          ? _buildStudyPlanView(isSmallScreen)
          : _buildOnboardingFlow(isSmallScreen),
    );
  }
  
  Widget _buildOnboardingFlow(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: const Color(0xFFF5F5F7),
        child: Column(
          children: [
            _buildOnboardingHeader(isSmallScreen),
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildCurrentStep(isSmallScreen),
                  ),
                ),
              ),
            ),
            _buildNavigationButtons(isSmallScreen),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOnboardingHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Create Your Study Plan',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 26 : 32,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Get AI-powered recommendations for BECE and end-of-term success',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 14 : 16,
              color: const Color(0xFF86868B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 14, color: Color(0xFF34C759)),
                const SizedBox(width: 6),
                Text(
                  'Takes less than 1 minute',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(1, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          final stepNames = ['Exam Focus'];
          
          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? const Color(0xFF0071E3)
                          : const Color(0xFFF5F5F7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted || isCurrent
                            ? const Color(0xFF0071E3)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                          : Text(
                              '${index + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isCurrent ? Colors.white : const Color(0xFF86868B),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stepNames[index],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent ? const Color(0xFF1D1D1F) : const Color(0xFF86868B),
                    ),
                  ),
                ],
              ),
              if (index < 1)
                Container(
                  width: 60,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF0071E3)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
  
  Widget _buildCurrentStep(bool isSmallScreen) {
    switch (_currentStep) {
      case 0:
        return _buildExamFocusStep(isSmallScreen);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildExamFocusStep(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you preparing for?',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your exam focus to get personalized recommendations',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF86868B),
            ),
          ),
          const SizedBox(height: 32),
          
          // BECE 2026 Option
          _buildExamTypeCard(
            title: 'BECE 2026',
            subtitle: 'Prepare for the Basic Education Certificate Examination',
            icon: Icons.school_rounded,
            color: const Color(0xFF667EEA),
            isSelected: _examType == 'BECE 2026',
            onTap: () {
              setState(() {
                _examType = 'BECE 2026';
                _examDate = DateTime(2026, 6, 1);
              });
            },
            daysUntil: DateTime(2026, 6, 1).difference(DateTime.now()).inDays,
          ),
          
          const SizedBox(height: 16),
          
          // End-of-Term Options
          Text(
            'End-of-Term Exams',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 12),
          
          _buildExamTypeCard(
            title: 'End-of-Term 1',
            subtitle: 'November/December Assessment',
            icon: Icons.event,
            color: const Color(0xFF0071E3),
            isSelected: _examType == 'End-of-Term 1',
            onTap: () {
              setState(() {
                _examType = 'End-of-Term 1';
                _examDate = _getNextEndOfTermDate(1);
              });
            },
            compact: true,
          ),
          
          const SizedBox(height: 12),
          
          _buildExamTypeCard(
            title: 'End-of-Term 2',
            subtitle: 'March/April Assessment',
            icon: Icons.event,
            color: const Color(0xFF34C759),
            isSelected: _examType == 'End-of-Term 2',
            onTap: () {
              setState(() {
                _examType = 'End-of-Term 2';
                _examDate = _getNextEndOfTermDate(2);
              });
            },
            compact: true,
          ),
          
          const SizedBox(height: 12),
          
          _buildExamTypeCard(
            title: 'End-of-Term 3',
            subtitle: 'July/August Assessment',
            icon: Icons.event,
            color: const Color(0xFFFF9500),
            isSelected: _examType == 'End-of-Term 3',
            onTap: () {
              setState(() {
                _examType = 'End-of-Term 3';
                _examDate = _getNextEndOfTermDate(3);
              });
            },
            compact: true,
          ),
        ],
      ),
    );
  }
  
  DateTime _getNextEndOfTermDate(int term) {
    final now = DateTime.now();
    int year = now.year;
    int month;
    
    switch (term) {
      case 1:
        month = 11; // November
        if (now.month > 11) year++;
        break;
      case 2:
        month = 3; // March
        if (now.month > 3) year++;
        break;
      case 3:
        month = 7; // July
        if (now.month > 7) year++;
        break;
      default:
        month = 11;
    }
    
    return DateTime(year, month, 15);
  }
  
  Map<String, List<Map<String, dynamic>>> _createDailySchedule() {
    final schedule = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final daysUntilExam = _examDate?.difference(now).inDays ?? 180;
    
    // Create 30-day rolling schedule
    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dayOfWeek = date.weekday; // 1=Monday, 7=Sunday
      
      final dailyTasks = <Map<String, dynamic>>[];
      
      // Morning: Textbook reading (rotate subjects)
      final morningSubject = _beceSubjects[i % _beceSubjects.length];
      dailyTasks.add({
        'time': 'Morning',
        'type': 'Textbook',
        'subject': morningSubject['name'],
        'icon': morningSubject['icon'],
        'color': morningSubject['color'],
        'title': 'Read ${morningSubject['name']} Chapter',
        'duration': '30 min',
      });
      
      // Afternoon: Past questions (prioritize weak subjects first)
      final afternoonSubject = _beceSubjects[(i + 3) % _beceSubjects.length];
      dailyTasks.add({
        'time': 'Afternoon',
        'type': 'Past Questions',
        'subject': afternoonSubject['name'],
        'icon': Icons.quiz,
        'color': afternoonSubject['color'],
        'title': '${afternoonSubject['name']} Practice Questions',
        'duration': '45 min',
      });
      
      // Evening: Review or additional practice
      if (dayOfWeek <= 5) { // Weekdays
        final eveningSubject = _beceSubjects[(i + 5) % _beceSubjects.length];
        dailyTasks.add({
          'time': 'Evening',
          'type': 'Review',
          'subject': eveningSubject['name'],
          'icon': Icons.auto_stories,
          'color': eveningSubject['color'],
          'title': 'Review ${eveningSubject['name']} Notes',
          'duration': '30 min',
        });
      } else { // Weekends - mixed review
        dailyTasks.add({
          'time': 'Evening',
          'type': 'Mixed Review',
          'subject': 'All Subjects',
          'icon': Icons.checklist,
          'color': const Color(0xFF667EEA),
          'title': 'Weekly Review Quiz',
          'duration': '60 min',
        });
      }
      
      schedule[dateKey] = dailyTasks;
    }
    
    return schedule;
  }
  
  Widget _buildExamTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    int? daysUntil,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: compact ? 20 : 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF86868B),
                    ),
                  ),
                  if (daysUntil != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysUntil days away',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubjectSelectionStep(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your subjects',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the subjects you want to focus on for $_examType',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF86868B),
            ),
          ),
          const SizedBox(height: 24),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isSmallScreen ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isSmallScreen ? 1.1 : 1.3,
            ),
            itemCount: _beceSubjects.length,
            itemBuilder: (context, index) {
              final subject = _beceSubjects[index];
              final isSelected = _selectedSubjects.any((s) => s['name'] == subject['name']);
              
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedSubjects.removeWhere((s) => s['name'] == subject['name']);
                    } else {
                      _selectedSubjects.add(subject);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (subject['color'] as Color).withValues(alpha: 0.1)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? (subject['color'] as Color) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        subject['icon'] as IconData,
                        color: subject['color'] as Color,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subject['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D1D1F),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 6),
                        Icon(
                          Icons.check_circle,
                          color: subject['color'] as Color,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          
          if (_selectedSubjects.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF667EEA), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedSubjects.length} subjects selected · Study plan will prioritize these subjects',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF667EEA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // OLD UNUSED METHODS - Kept for reference but not called by simplified wizard
  /*
  Widget _buildCommitmentsStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 2: When are you available to study?',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Weekly study hours: $_weeklyHours hours',
              style: AppStyles.montserratMedium(fontSize: 16),
            ),
            Slider(
              value: _weeklyHours.toDouble(),
              min: 1,
              max: 40,
              divisions: 39,
              label: '$_weeklyHours hours',
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _weeklyHours = value.round());
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Preferred study time:',
              style: AppStyles.montserratBold(
                fontSize: 16,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Morning', 'Afternoon', 'Evening'].map((time) {
                return ChoiceChip(
                  label: Text(time),
                  selected: _preferredTime == time,
                  onSelected: (selected) {
                    setState(() => _preferredTime = time);
                  },
                  selectedColor: AppStyles.primaryRed.withValues(alpha: 0.2),
                  labelStyle: AppStyles.montserratMedium(
                    color: _preferredTime == time
                        ? AppStyles.primaryRed
                        : Colors.grey[700]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Mark your available times (Optional)',
              style: AppStyles.montserratBold(
                fontSize: 16,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                columns: [
                  const DataColumn(label: Text('Day')),
                  ...['Morning', 'Afternoon', 'Evening']
                      .map((time) => DataColumn(label: Text(time)))
                      .toList(),
                ],
                rows: _availability.keys.map((day) {
                  return DataRow(
                    cells: [
                      DataCell(Text(day.substring(0, 3))),
                      ..._availability[day]!.keys.map((time) {
                        return DataCell(
                          Checkbox(
                            value: _availability[day]![time],
                            onChanged: (value) {
                              setState(() {
                                _availability[day]![time] = value ?? false;
                              });
                            },
                            activeColor: AppStyles.primaryRed,
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubjectsStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 3: What subjects will you study?',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Quick add BECE subjects:',
              style: AppStyles.montserratBold(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _beceSubjects.map((subject) {
                final alreadyAdded = _subjects.any((s) => s['name'] == subject);
                return FilterChip(
                  label: Text(subject),
                  selected: alreadyAdded,
                  onSelected: alreadyAdded
                      ? null
                      : (_) {
                          setState(() {
                            _subjects.add({
                              'name': subject,
                              'priority': 'Medium',
                              'hoursNeeded': 0,
                            });
                          });
                        },
                  selectedColor: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF2ECC71),
                  labelStyle: AppStyles.montserratMedium(fontSize: 12),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Or add custom subject:',
              style: AppStyles.montserratBold(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      hintText: 'Subject name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_subjectController.text.trim().isNotEmpty) {
                      setState(() {
                        _subjects.add({
                          'name': _subjectController.text.trim(),
                          'priority': _subjectPriority,
                          'hoursNeeded': 0,
                        });
                        _subjectController.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            if (_subjects.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Your subjects (${_subjects.length}):',
                style: AppStyles.montserratBold(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        subject['name'],
                        style: AppStyles.montserratMedium(),
                      ),
                      subtitle: Text(
                        'Priority: ${subject['priority']}',
                        style: AppStyles.montserratRegular(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _subjects.removeAt(index));
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPreferencesStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 4: Study session preferences',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Study session length: $_sessionLength minutes',
              style: AppStyles.montserratMedium(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _sessionLength.toDouble(),
              min: 15,
              max: 120,
              divisions: 21,
              label: '$_sessionLength min',
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _sessionLength = value.round());
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Break length: $_breakLength minutes',
              style: AppStyles.montserratMedium(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _breakLength.toDouble(),
              min: 5,
              max: 30,
              divisions: 5,
              label: '$_breakLength min',
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _breakLength = value.round());
              },
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(
                'Enable push notifications',
                style: AppStyles.montserratMedium(),
              ),
              subtitle: Text(
                'Get reminders for your study sessions',
                style: AppStyles.montserratRegular(fontSize: 12),
              ),
              value: _enableReminders,
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _enableReminders = value);
              },
            ),
            SwitchListTile(
              title: Text(
                'Enable email reminders',
                style: AppStyles.montserratMedium(),
              ),
              subtitle: Text(
                'Receive study reminders via email',
                style: AppStyles.montserratRegular(fontSize: 12),
              ),
              value: _enableEmailReminders,
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _enableEmailReminders = value);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviewStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 5: Review your plan',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            _buildReviewItem('Goal', _studyGoal),
            if (_examDate != null)
              _buildReviewItem(
                'Exam Date',
                DateFormat('MMMM d, y').format(_examDate!),
              ),
            _buildReviewItem('Weekly Hours', '$_weeklyHours hours'),
            _buildReviewItem('Preferred Time', _preferredTime),
            _buildReviewItem('Subjects', '${_subjects.length} selected'),
            _buildReviewItem('Session Length', '$_sessionLength minutes'),
            _buildReviewItem('Break Length', '$_breakLength minutes'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppStyles.primaryRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can always edit your plan later',
                      style: AppStyles.montserratMedium(
                        color: AppStyles.primaryRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: AppStyles.montserratBold(fontSize: 14),
          ),
          Text(
            value,
            style: AppStyles.montserratRegular(fontSize: 14),
          ),
        ],
      ),
    );
  }
  */
  // END OF OLD UNUSED METHODS
  
  Widget _buildNavigationButtons(bool isSmallScreen) {
    final canProceed = true; // Always can proceed from exam selection
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () {
                setState(() => _currentStep--);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0071E3), width: 1.5),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, size: 18, color: Color(0xFF0071E3)),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0071E3),
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF86868B),
                ),
              ),
            ),
          ElevatedButton(
            onPressed: !canProceed || _isGeneratingPlan
                ? null
                : () {
                    _generateStudyPlan();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0071E3),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFF5F5F7),
              disabledForegroundColor: const Color(0xFF86868B),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 28 : 40,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isGeneratingPlan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create Study Plan',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStudyPlanView(bool isSmallScreen) {
    final dailySchedule = _generatedPlan?['dailySchedule'] as Map<String, dynamic>? ?? {};
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text('Your Study Plan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0071E3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _createNewPlan,
            tooltip: 'Create New Plan',
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        itemCount: dailySchedule.length,
        itemBuilder: (context, index) {
          final dateKey = dailySchedule.keys.elementAt(index);
          final tasks = dailySchedule[dateKey] as List;
          final date = DateTime.parse(dateKey);
          final isToday = dateKey == today;
          final isPast = date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isToday ? Border.all(color: const Color(0xFF0071E3), width: 2) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF0071E3).withValues(alpha: 0.1) : const Color(0xFFF5F5F7),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isToday ? Icons.today : Icons.calendar_today,
                        size: 20,
                        color: isToday ? const Color(0xFF0071E3) : const Color(0xFF86868B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMM d').format(date),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isToday ? const Color(0xFF0071E3) : const Color(0xFF1D1D1F),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0071E3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Today',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Tasks
                ...tasks.map((task) {
                  final isCompleted = _sessionCompletions[dateKey]?[tasks.indexOf(task)] ?? false;
                  return InkWell(
                    onTap: () async {
                      await _toggleSessionCompletion(dateKey, tasks.indexOf(task));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: tasks.indexOf(task) < tasks.length - 1
                              ? BorderSide(color: Colors.black.withValues(alpha: 0.06))
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: (task['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              task['icon'] as IconData,
                              color: task['color'] as Color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['title'],
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1D1D1F),
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      task['time'],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF86868B),
                                      ),
                                    ),
                                    Text(
                                      ' • ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF86868B),
                                      ),
                                    ),
                                    Text(
                                      task['duration'],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF86868B),
                                      ),
                                    ),
                                    Text(
                                      ' • ',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF86868B),
                                      ),
                                    ),
                                    Text(
                                      task['type'],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: task['color'] as Color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: isCompleted,
                            onChanged: (_) async {
                              await _toggleSessionCompletion(dateKey, tasks.indexOf(task));
                            },
                            activeColor: const Color(0xFF34C759),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /*
  // OLD _buildStudyPlanView - needs AppStyles migration
  Widget _buildStudyPlanViewOld(bool isSmallScreen) {
    final weeklySchedule = _generatedPlan?['weeklySchedule'] as Map<String, dynamic>?;
    final tips = _generatedPlan?['tips'] as List<dynamic>?;
    final studyTechniques = _generatedPlan?['studyTechniques'] as List<dynamic>?;
    
    // Calculate progress
    int totalSessions = 0;
    int completedSessions = 0;
    weeklySchedule?.forEach((day, sessions) {
      if (sessions is List) {
        totalSessions += sessions.length;
        sessions.asMap().forEach((index, session) {
          if (_sessionCompletions[day]?[index] == true) {
            completedSessions++;
          }
        });
      }
    });
    
    final progressPercent = totalSessions > 0 ? (completedSessions / totalSessions * 100).toInt() : 0;
    
    return Container(
      color: AppStyles.warmWhite,
      child: Stack(
        children: [
          Column(
            children: [
              // Compact Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 24,
                  vertical: isSmallScreen ? 12 : 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSmallScreen
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Study Plan',
                            style: AppStyles.playfairHeading(
                              fontSize: 20,
                              color: AppStyles.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Week $_currentWeek • $progressPercent% Complete',
                                  style: AppStyles.montserratMedium(
                                    fontSize: 12,
                                    color: const Color(0xFF2ECC71),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Study Plan',
                                  style: AppStyles.playfairHeading(
                                    fontSize: 32,
                                    color: AppStyles.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Week $_currentWeek • $progressPercent% Complete',
                                  style: AppStyles.montserratMedium(
                                    fontSize: 14,
                                    color: const Color(0xFF2ECC71),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _createNewPlan,
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(
                              'Create New',
                              style: AppStyles.montserratBold(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStyles.primaryRed,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44), // Minimum 44pt tap target
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 32),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Progress Card
                      Card(
                        elevation: isSmallScreen ? 1 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up,
                                      color: Color(0xFF2ECC71),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your Progress',
                                          style: AppStyles.montserratBold(
                                            fontSize: isSmallScreen ? 16 : 18,
                                            color: AppStyles.primaryNavy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$completedSessions of $totalSessions sessions completed',
                                          style: AppStyles.montserratRegular(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: Colors.grey[600]!,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$progressPercent%',
                                    style: AppStyles.montserratBold(
                                      fontSize: 32,
                                      color: const Color(0xFF2ECC71),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progressPercent / 100,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Weekly Schedule
                      Text(
                        'Weekly Schedule',
                        style: AppStyles.montserratBold(
                          fontSize: 22,
                          color: AppStyles.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (weeklySchedule != null)
                        ...weeklySchedule.entries.map((entry) {
                          final day = entry.key;
                          final sessions = entry.value as List<dynamic>;
                          
                          return Card(
                            elevation: isSmallScreen ? 1 : 2,
                            margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6A00F4).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF6A00F4),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        day,
                                        style: AppStyles.montserratBold(
                                          fontSize: 18,
                                          color: AppStyles.primaryNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...sessions.asMap().entries.map((sessionEntry) {
                                    final sessionIndex = sessionEntry.key;
                                    final session = sessionEntry.value as Map<String, dynamic>;
                                    final isCompleted = _sessionCompletions[day]?[sessionIndex] ?? false;
                                    
                                    return InkWell(
                                      onTap: () => _toggleSessionCompletion(day, sessionIndex),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
                                              : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isCompleted
                                                ? const Color(0xFF2ECC71)
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 44,
                                              width: 44,
                                              child: Checkbox(
                                                value: isCompleted,
                                                onChanged: (val) => _toggleSessionCompletion(day, sessionIndex),
                                                activeColor: const Color(0xFF2ECC71),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    session['subject'] ?? 'Study Session',
                                                    style: AppStyles.montserratBold(
                                                      fontSize: isSmallScreen ? 14 : 16,
                                                      color: AppStyles.primaryNavy,
                                                    ).copyWith(
                                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    session['topic'] ?? '',
                                                    style: AppStyles.montserratRegular(
                                                      fontSize: isSmallScreen ? 12 : 14,
                                                      color: Colors.grey[700]!,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 4,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            session['time'] ?? '',
                                                            style: AppStyles.montserratMedium(
                                                              fontSize: 11,
                                                              color: Colors.grey[600]!,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.task_alt, size: 14, color: Colors.grey[600]),
                                                          const SizedBox(width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              session['activity'] ?? '',
                                                              style: AppStyles.montserratMedium(
                                                                fontSize: 11,
                                                                color: Colors.grey[600]!,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      
                      const SizedBox(height: 24),
                      
                      // Study Techniques
                      if (studyTechniques != null && studyTechniques.isNotEmpty) ...[
                        Text(
                          'Recommended Study Techniques',
                          style: AppStyles.montserratBold(
                            fontSize: 22,
                            color: AppStyles.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: isSmallScreen ? 1 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                            child: Column(
                              children: studyTechniques.map((technique) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF6A00F4),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          technique.toString(),
                                          style: AppStyles.montserratRegular(
                                            fontSize: 15,
                                            color: Colors.grey[800]!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Tips
                      if (tips != null && tips.isNotEmpty) ...[
                        Text(
                          'Success Tips',
                          style: AppStyles.montserratBold(
                            fontSize: 22,
                            color: AppStyles.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: tips.map((tip) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.lightbulb_outline,
                                        color: Color(0xFF2ECC71),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          tip.toString(),
                                          style: AppStyles.montserratRegular(
                                            fontSize: 15,
                                            color: Colors.grey[800]!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Add bottom padding for FAB on mobile
                      if (isSmallScreen) const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        // Floating Action Button for mobile
        if (isSmallScreen)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _createNewPlan,
              backgroundColor: AppStyles.primaryRed,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New Plan',
                style: AppStyles.montserratBold(color: Colors.white),
              ),
            ),
          ),
      ],
    ),
    );
  }
  */
}
