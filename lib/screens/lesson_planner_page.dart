import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'dart:html' as html;
import '../constants/app_styles.dart';

class LessonPlannerPage extends StatefulWidget {
  const LessonPlannerPage({Key? key}) : super(key: key);

  @override
  State<LessonPlannerPage> createState() => _LessonPlannerPageState();
}

class _LessonPlannerPageState extends State<LessonPlannerPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Onboarding state
  int _currentStep = 0;
  bool _hasCompletedSetup = false;
  bool _isLoadingSetup = false;
  bool _isGeneratingLesson = false;
  
  // Step 1: Teacher Profile
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _circuitController = TextEditingController();
  final _districtController = TextEditingController();
  String _region = 'Greater Accra';
  String _level = 'JHS';
  
  final List<String> _ghanaRegions = [
    'Greater Accra', 'Ashanti', 'Western', 'Eastern', 'Central',
    'Northern', 'Upper East', 'Upper West', 'Volta', 'Bono',
    'Bono East', 'Ahafo', 'Savannah', 'North East', 'Western North', 'Oti'
  ];
  
  // Step 2: Subject Selection
  final List<Map<String, dynamic>> _teachingSubjects = [];
  int _periodsPerWeek = 20;
  
  final Map<String, List<String>> _levelSubjects = {
    'Primary': ['English', 'Mathematics', 'Science', 'Social Studies', 'RME', 'Creative Arts', 'ICT', 'Ghanaian Language'],
    'JHS': ['English', 'Mathematics', 'Integrated Science', 'Social Studies', 'RME', 'Creative Arts', 'ICT', 'Ghanaian Language', 'French'],
    'SHS': ['Core Mathematics', 'Elective Mathematics', 'English', 'Integrated Science', 'Social Studies', 'Physics', 'Chemistry', 'Biology', 'Economics', 'Geography', 'History', 'Government', 'ICT'],
  };
  
  // Step 3: Curriculum Navigation
  String _selectedTerm = 'Term 1';
  final Map<String, dynamic> _subjectCurriculum = {};
  
  // Step 4: Class Setup
  final List<Map<String, dynamic>> _classes = [];
  
  // Step 5: Schedule Configuration
  final Map<String, List<String>> _weeklySchedule = {};
  int _periodDuration = 40; // minutes
  
  // Step 6: Goals & Preferences
  String _planningGoal = 'Better organized lessons';
  String _planningStyle = 'Detailed';
  bool _enableReminders = true;
  
  // Lesson Planning State
  String? _selectedSubjectForPlanning;
  String? _selectedStrand;
  String? _selectedSubStrand;
  String? _selectedIndicator;
  final _lessonTitleController = TextEditingController();
  final _lessonObjectivesController = TextEditingController();
  
  // Core Competencies
  final List<String> _selectedCompetencies = [];
  final List<String> _coreCompetencies = [
    'Critical Thinking & Problem Solving',
    'Communication & Collaboration',
    'Cultural Identity & Global Citizenship',
    'Personal Development & Leadership',
    'Creativity & Innovation',
    'Digital Literacy',
  ];
  
  // Values
  final List<String> _selectedValues = [];
  final List<String> _ghanaianValues = [
    'Respect', 'Integrity', 'Excellence', 'Commitment', 'Teamwork', 'Patriotism',
  ];
  
  // Generated Lessons
  List<Map<String, dynamic>> _generatedLessons = [];
  Map<String, dynamic>? _currentViewingLesson;
  
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
    _checkExistingSetup();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _schoolNameController.dispose();
    _circuitController.dispose();
    _districtController.dispose();
    _lessonTitleController.dispose();
    _lessonObjectivesController.dispose();
    super.dispose();
  }
  
  Future<void> _checkExistingSetup() async {
    setState(() => _isLoadingSetup = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('teacher_planner_setup')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        // Load existing lesson plans
        final lessonsSnapshot = await FirebaseFirestore.instance
            .collection('lesson_plans')
            .doc(user.uid)
            .collection('plans')
            .orderBy('createdAt', descending: true)
            .get();
        
        final lessons = lessonsSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList();
        
        setState(() {
          _hasCompletedSetup = true;
          _generatedLessons = lessons;
          // Load saved data if needed
        });
      }
    } catch (e) {
      debugPrint('Error checking setup: $e');
    } finally {
      setState(() => _isLoadingSetup = false);
    }
  }
  
  Future<void> _saveSetup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('teacher_planner_setup')
          .doc(user.uid)
          .set({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'schoolName': _schoolNameController.text,
        'circuit': _circuitController.text,
        'district': _districtController.text,
        'region': _region,
        'level': _level,
        'subjects': _teachingSubjects,
        'periodsPerWeek': _periodsPerWeek,
        'classes': _classes,
        'weeklySchedule': _weeklySchedule,
        'periodDuration': _periodDuration,
        'planningGoal': _planningGoal,
        'planningStyle': _planningStyle,
        'enableReminders': _enableReminders,
        'setupCompletedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() => _hasCompletedSetup = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Setup complete! Let\'s create your first lesson plan'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving setup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving setup: $e'),
            backgroundColor: const Color(0xFFD62828),
          ),
        );
      }
    }
  }
  
  Future<void> _generateLessonPlan() async {
    setState(() => _isGeneratingLesson = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final lessonData = {
        'userId': user.uid,
        'subject': _selectedSubjectForPlanning,
        'strand': _selectedStrand,
        'subStrand': _selectedSubStrand,
        'indicator': _selectedIndicator,
        'title': _lessonTitleController.text,
        'objectives': _lessonObjectivesController.text,
        'competencies': _selectedCompetencies,
        'values': _selectedValues,
        'level': _level,
        'duration': _periodDuration,
      };
      
      // Call Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('generateLessonPlan');
      final result = await callable.call(lessonData);
      
      // Extract the lesson plan from the response
      final lessonPlan = result.data['lessonPlan'];
      final metadata = result.data['metadata'];
      
      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('lesson_plans')
          .doc(user.uid)
          .collection('plans')
          .add({
        ...lessonData,
        'lessonPlan': lessonPlan,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Add to local list
      setState(() {
        _generatedLessons.insert(0, {
          'id': docRef.id,
          ...lessonData,
          'lessonPlan': lessonPlan,
          'metadata': metadata,
        });
        _currentViewingLesson = _generatedLessons[0];
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lesson plan generated successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error generating lesson: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFD62828),
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingLesson = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    
    if (_isLoadingSetup) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_hasCompletedSetup) {
      return _buildLessonPlannerView(isSmallScreen);
    }
    
    return _buildOnboardingFlow(isSmallScreen);
  }
  
  Widget _buildOnboardingFlow(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: AppStyles.warmWhite,
        child: Column(
          children: [
            _buildOnboardingHeader(isSmallScreen),
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
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
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'GES/NaCCA Lesson Planner Setup',
            style: AppStyles.playfairHeading(
              fontSize: isSmallScreen ? 24 : 32,
              color: AppStyles.primaryNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create curriculum-aligned lesson plans with AI assistance',
            style: AppStyles.montserratRegular(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[600]!,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '⏱️ 5-7 minutes to set up',
            style: AppStyles.montserratMedium(
              fontSize: 12,
              color: const Color(0xFF2ECC71),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) {
            final isCompleted = index < _currentStep;
            final isCurrent = index == _currentStep;
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppStyles.primaryRed
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: AppStyles.montserratBold(
                              fontSize: 12,
                              color: isCurrent ? Colors.white : Colors.grey[600]!,
                            ),
                          ),
                  ),
                ),
                if (index < 6)
                  Container(
                    width: 30,
                    height: 2,
                    color: index < _currentStep
                        ? AppStyles.primaryRed
                        : Colors.grey[300],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
  
  Widget _buildCurrentStep(bool isSmallScreen) {
    switch (_currentStep) {
      case 0:
        return _buildTeacherProfileStep(isSmallScreen);
      case 1:
        return _buildSubjectSelectionStep(isSmallScreen);
      case 2:
        return _buildCurriculumNavigationStep(isSmallScreen);
      case 3:
        return _buildClassSetupStep(isSmallScreen);
      case 4:
        return _buildScheduleConfigurationStep(isSmallScreen);
      case 5:
        return _buildGoalsPreferencesStep(isSmallScreen);
      case 6:
        return _buildReviewStep(isSmallScreen);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildTeacherProfileStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 1: Teacher Profile',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'Enter your full name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      hintText: '024XXXXXXX',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'teacher@school.edu.gh',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'School Details',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _schoolNameController,
              decoration: InputDecoration(
                labelText: 'School Name *',
                hintText: 'e.g., Accra Academy',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _circuitController,
                    decoration: InputDecoration(
                      labelText: 'Circuit',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _districtController,
                    decoration: InputDecoration(
                      labelText: 'District',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _region,
              decoration: InputDecoration(
                labelText: 'Region *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _ghanaRegions.map((region) {
                return DropdownMenuItem(value: region, child: Text(region));
              }).toList(),
              onChanged: (value) {
                setState(() => _region = value!);
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Level Taught *',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Primary', 'JHS', 'SHS'].map((level) {
                return ChoiceChip(
                  label: Text(level),
                  selected: _level == level,
                  onSelected: (selected) {
                    setState(() => _level = level);
                  },
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                  labelStyle: AppStyles.montserratMedium(
                    color: _level == level ? AppStyles.primaryRed : Colors.grey[700]!,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubjectSelectionStep(bool isSmallScreen) {
    final subjects = _levelSubjects[_level] ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 2: Select Subjects You Teach',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select from $_level subjects:',
              style: AppStyles.montserratBold(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((subject) {
                final isSelected = _teachingSubjects.any((s) => s['name'] == subject);
                return FilterChip(
                  label: Text(subject),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _teachingSubjects.add({
                          'name': subject,
                          'hoursPerWeek': 0,
                        });
                      } else {
                        _teachingSubjects.removeWhere((s) => s['name'] == subject);
                      }
                    });
                  },
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                  checkmarkColor: AppStyles.primaryRed,
                  labelStyle: AppStyles.montserratMedium(fontSize: 12),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Teaching Load: $_periodsPerWeek periods/week',
              style: AppStyles.montserratMedium(fontSize: 16),
            ),
            Slider(
              value: _periodsPerWeek.toDouble(),
              min: 5,
              max: 40,
              divisions: 35,
              label: '$_periodsPerWeek periods',
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _periodsPerWeek = value.round());
              },
            ),
            if (_teachingSubjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Selected Subjects (${_teachingSubjects.length}):',
                style: AppStyles.montserratBold(fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...(_teachingSubjects.map((subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          subject['name'],
                          style: AppStyles.montserratRegular(),
                        ),
                      ],
                    ),
                  ))),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurriculumNavigationStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 3: Curriculum Setup',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select current term:',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Term 1', 'Term 2', 'Term 3'].map((term) {
                return ChoiceChip(
                  label: Text(term),
                  selected: _selectedTerm == term,
                  onSelected: (selected) {
                    setState(() => _selectedTerm = term);
                  },
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                  labelStyle: AppStyles.montserratMedium(
                    color: _selectedTerm == term ? AppStyles.primaryRed : Colors.grey[700]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can set up detailed curriculum strands and learning indicators after setup',
                      style: AppStyles.montserratRegular(
                        color: Colors.blue[900]!,
                        fontSize: 12,
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
  
  Widget _buildClassSetupStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 4: Add Your Classes',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddClassDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Class'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_classes.isNotEmpty) ...[
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final classInfo = _classes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.class_, color: AppStyles.primaryNavy),
                      title: Text(
                        classInfo['name'],
                        style: AppStyles.montserratMedium(),
                      ),
                      subtitle: Text(
                        'Size: ${classInfo['size']} students',
                        style: AppStyles.montserratRegular(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _classes.removeAt(index));
                        },
                      ),
                    ),
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'No classes added yet',
                style: AppStyles.montserratRegular(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleConfigurationStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 5: Schedule Configuration',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Period duration: $_periodDuration minutes',
              style: AppStyles.montserratMedium(fontSize: 16),
            ),
            Slider(
              value: _periodDuration.toDouble(),
              min: 30,
              max: 90,
              divisions: 12,
              label: '$_periodDuration min',
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _periodDuration = value.round());
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can set up your detailed weekly timetable after completing setup',
                      style: AppStyles.montserratRegular(
                        color: Colors.blue[900]!,
                        fontSize: 12,
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
  
  Widget _buildGoalsPreferencesStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 6: Goals & Preferences',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'What do you want to achieve?',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Better organized lessons',
                'Track curriculum coverage',
                'Collaborate with colleagues',
                'Generate reports faster',
              ].map((goal) {
                return ChoiceChip(
                  label: Text(goal),
                  selected: _planningGoal == goal,
                  onSelected: (selected) {
                    setState(() => _planningGoal = goal);
                  },
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                  labelStyle: AppStyles.montserratMedium(
                    fontSize: 12,
                    color: _planningGoal == goal ? AppStyles.primaryRed : Colors.grey[700]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Planning style:',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Detailed', 'Brief', 'Moderate'].map((style) {
                return ChoiceChip(
                  label: Text(style),
                  selected: _planningStyle == style,
                  onSelected: (selected) {
                    setState(() => _planningStyle = style);
                  },
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                  labelStyle: AppStyles.montserratMedium(
                    color: _planningStyle == style ? AppStyles.primaryRed : Colors.grey[700]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(
                'Enable reminders',
                style: AppStyles.montserratMedium(),
              ),
              subtitle: Text(
                'Get notified about lesson planning tasks',
                style: AppStyles.montserratRegular(fontSize: 12),
              ),
              value: _enableReminders,
              activeColor: AppStyles.primaryRed,
              onChanged: (value) {
                setState(() => _enableReminders = value);
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
              'Step 7: Review Your Setup',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            _buildReviewItem('Name', _nameController.text),
            _buildReviewItem('School', _schoolNameController.text),
            _buildReviewItem('Region', _region),
            _buildReviewItem('Level', _level),
            _buildReviewItem('Subjects', '${_teachingSubjects.length} selected'),
            _buildReviewItem('Classes', '${_classes.length} added'),
            _buildReviewItem('Period Duration', '$_periodDuration minutes'),
            _buildReviewItem('Planning Goal', _planningGoal),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppStyles.primaryRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can update your profile and preferences anytime',
                      style: AppStyles.montserratMedium(
                        color: AppStyles.primaryRed,
                        fontSize: 12,
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
  
  Widget _buildNavigationButtons(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
                side: const BorderSide(color: AppStyles.primaryRed),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back',
                style: AppStyles.montserratMedium(
                  color: AppStyles.primaryRed,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: () {
              if (_currentStep < 6) {
                setState(() => _currentStep++);
              } else {
                _saveSetup();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primaryRed,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 32 : 48,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _currentStep < 6 ? 'Next' : 'Complete Setup',
              style: AppStyles.montserratBold(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLessonPlannerView(bool isSmallScreen) {
    return Container(
      color: AppStyles.warmWhite,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Responsive header layout
                if (isSmallScreen)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lesson Planner',
                        style: AppStyles.playfairHeading(
                          fontSize: 28,
                          color: AppStyles.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create GES/NaCCA aligned lesson plans',
                        style: AppStyles.montserratRegular(
                          fontSize: 14,
                          color: Colors.grey[600]!,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCreateLessonDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('New Lesson'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lesson Planner',
                              style: AppStyles.playfairHeading(
                                fontSize: 36,
                                color: AppStyles.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create GES/NaCCA aligned lesson plans',
                              style: AppStyles.montserratRegular(
                                fontSize: 16,
                                color: Colors.grey[600]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateLessonDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('New Lesson'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                // Quick stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Lesson Plans',
                        '${_generatedLessons.length}',
                        Icons.book,
                        AppStyles.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Subjects',
                        '${_teachingSubjects.length}',
                        Icons.subject,
                        const Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Classes',
                        '${_classes.length}',
                        Icons.class_,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Lesson plans list
                if (_generatedLessons.isEmpty)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No lesson plans yet',
                              style: AppStyles.montserratBold(
                                fontSize: 18,
                                color: Colors.grey[700]!,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first lesson plan to get started',
                              style: AppStyles.montserratRegular(
                                color: Colors.grey[600]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ..._generatedLessons.map((lesson) {
                    final lessonPlan = lesson['lessonPlan'] as Map<String, dynamic>?;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentViewingLesson = lesson;
                          });
                          _showLessonDetailsDialog(context, lesson);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppStyles.primaryRed.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.book,
                                      color: AppStyles.primaryRed,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lessonPlan?['lessonTitle'] ?? lesson['title'] ?? 'Untitled Lesson',
                                          style: AppStyles.montserratBold(
                                            fontSize: 18,
                                            color: AppStyles.primaryNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lesson['subject'] ?? '',
                                          style: AppStyles.montserratMedium(
                                            fontSize: 14,
                                            color: Colors.grey[600]!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red[400],
                                    ),
                                    tooltip: 'Delete lesson',
                                    onPressed: () {
                                      _showDeleteConfirmationDialog(context, lesson);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (lessonPlan?['learningOutcomes'] != null)
                                Text(
                                  (lessonPlan!['learningOutcomes'] as List).isNotEmpty
                                      ? (lessonPlan['learningOutcomes'] as List)[0].toString()
                                      : '',
                                  style: AppStyles.montserratRegular(
                                    fontSize: 14,
                                    color: Colors.grey[700]!,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color),
                Text(
                  value,
                  style: AppStyles.montserratBold(
                    fontSize: 24,
                    color: AppStyles.primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppStyles.montserratRegular(
                fontSize: 12,
                color: Colors.grey[600]!,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddClassDialog(BuildContext context) {
    final classNameController = TextEditingController();
    final classSizeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Class',
          style: AppStyles.montserratBold(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: classNameController,
              decoration: InputDecoration(
                labelText: 'Class Name',
                hintText: 'e.g., JHS 2A',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: classSizeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Class Size',
                hintText: 'Number of students',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppStyles.montserratMedium()),
          ),
          ElevatedButton(
            onPressed: () {
              if (classNameController.text.isNotEmpty) {
                setState(() {
                  _classes.add({
                    'name': classNameController.text,
                    'size': int.tryParse(classSizeController.text) ?? 0,
                  });
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: Text('Add', style: AppStyles.montserratBold()),
          ),
        ],
      ),
    );
  }
  
  void _showCreateLessonDialog(BuildContext context) {
    _lessonTitleController.clear();
    _lessonObjectivesController.clear();
    _selectedCompetencies.clear();
    _selectedValues.clear();
    _selectedSubjectForPlanning = null;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create New Lesson Plan',
                          style: AppStyles.montserratBold(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject dropdown
                        Text(
                          'Subject *',
                          style: AppStyles.montserratBold(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedSubjectForPlanning,
                          decoration: InputDecoration(
                            hintText: 'Select a subject',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            // Primary Subjects
                            'English', 'Mathematics', 'Science', 'Social Studies', 'RME', 
                            'Creative Arts', 'ICT', 'Ghanaian Language',
                            // JHS Subjects
                            'Integrated Science', 'French',
                            // SHS Subjects
                            'Core Mathematics', 'Elective Mathematics', 
                            'Physics', 'Chemistry', 'Biology',
                            'Economics', 'Geography', 'History', 'Government',
                          ].map<DropdownMenuItem<String>>((subject) {
                            return DropdownMenuItem<String>(
                              value: subject,
                              child: Text(
                                subject,
                                style: AppStyles.montserratRegular(),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              _selectedSubjectForPlanning = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Lesson Title
                        Text(
                          'Lesson Title *',
                          style: AppStyles.montserratBold(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lessonTitleController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Introduction to Algebra',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: AppStyles.montserratRegular(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Learning Objectives
                        Text(
                          'Learning Objectives',
                          style: AppStyles.montserratBold(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lessonObjectivesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'What should students learn?',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          style: AppStyles.montserratRegular(fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        
                        // Core Competencies
                        Text(
                          'Core Competencies',
                          style: AppStyles.montserratBold(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _coreCompetencies.map((comp) {
                            final isSelected = _selectedCompetencies.contains(comp);
                            return FilterChip(
                              label: Text(
                                comp,
                                style: AppStyles.montserratRegular(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2ECC71),
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.grey[200],
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    _selectedCompetencies.add(comp);
                                  } else {
                                    _selectedCompetencies.remove(comp);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Values
                        Text(
                          'Ghanaian Values',
                          style: AppStyles.montserratBold(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _ghanaianValues.map((val) {
                            final isSelected = _selectedValues.contains(val);
                            return FilterChip(
                              label: Text(
                                val,
                                style: AppStyles.montserratRegular(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2ECC71),
                              checkmarkColor: Colors.white,
                              backgroundColor: Colors.grey[200],
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    _selectedValues.add(val);
                                  } else {
                                    _selectedValues.remove(val);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer with buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: AppStyles.montserratMedium(color: Colors.grey[700]!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isGeneratingLesson ? null : () async {
                          if (_lessonTitleController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a lesson title',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Color(0xFF2ECC71),
                              ),
                            );
                            return;
                          }
                          
                          if (_selectedSubjectForPlanning == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select a subject',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Color(0xFF2ECC71),
                              ),
                            );
                            return;
                          }
                          
                          Navigator.pop(dialogContext);
                          await _generateLessonPlan();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: _isGeneratingLesson
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Generate Lesson',
                                style: AppStyles.montserratBold(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to format lesson plan as text
  String _formatLessonPlanAsText(Map<String, dynamic> lesson) {
    final lessonPlan = lesson['lessonPlan'] as Map<String, dynamic>?;
    if (lessonPlan == null) return '';
    
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('GES/NACCA LESSON PLAN');
    buffer.writeln('═══════════════════════════════════════════════════════\n');
    
    // Metadata
    buffer.writeln('LESSON TITLE: ${lessonPlan['lessonTitle'] ?? 'N/A'}');
    buffer.writeln('SUBJECT: ${lesson['subject'] ?? 'N/A'}');
    buffer.writeln('LEVEL: ${lesson['level'] ?? 'N/A'}');
    buffer.writeln('DURATION: ${lesson['duration'] ?? 'N/A'} minutes\n');
    
    if (lessonPlan['metadata'] != null) {
      final metadata = lessonPlan['metadata'] as Map<String, dynamic>;
      if (metadata['strand'] != null) buffer.writeln('STRAND: ${metadata['strand']}');
      if (metadata['subStrand'] != null) buffer.writeln('SUB-STRAND: ${metadata['subStrand']}');
      if (metadata['indicator'] != null) buffer.writeln('INDICATOR: ${metadata['indicator']}');
      buffer.writeln();
    }
    
    // Learning Outcomes
    if (lessonPlan['learningOutcomes'] != null) {
      buffer.writeln('LEARNING OUTCOMES:');
      for (var outcome in lessonPlan['learningOutcomes'] as List) {
        buffer.writeln('  • $outcome');
      }
      buffer.writeln();
    }
    
    // Core Competencies
    if (lessonPlan['coreCompetencies'] != null && (lessonPlan['coreCompetencies'] as List).isNotEmpty) {
      buffer.writeln('CORE COMPETENCIES:');
      buffer.writeln('  ${(lessonPlan['coreCompetencies'] as List).join(', ')}');
      buffer.writeln();
    }
    
    // Values
    if (lessonPlan['values'] != null && (lessonPlan['values'] as List).isNotEmpty) {
      buffer.writeln('VALUES:');
      buffer.writeln('  ${(lessonPlan['values'] as List).join(', ')}');
      buffer.writeln();
    }
    
    // Prerequisites
    if (lessonPlan['prerequisites'] != null) {
      buffer.writeln('PREREQUISITES:');
      final prereqs = lessonPlan['prerequisites'];
      if (prereqs is List) {
        for (var prereq in prereqs) {
          buffer.writeln('  • $prereq');
        }
      } else {
        buffer.writeln('  $prereqs');
      }
      buffer.writeln();
    }
    
    // Teaching Learning Materials
    if (lessonPlan['teachingLearningMaterials'] != null) {
      buffer.writeln('TEACHING LEARNING MATERIALS:');
      final tlms = lessonPlan['teachingLearningMaterials'];
      if (tlms is List) {
        for (var tlm in tlms) {
          buffer.writeln('  • $tlm');
        }
      } else {
        buffer.writeln('  $tlms');
      }
      buffer.writeln();
    }
    
    // Lesson Structure
    if (lessonPlan['lessonStructure'] != null) {
      buffer.writeln('LESSON STRUCTURE:');
      buffer.writeln('─────────────────────────────────────────────────────\n');
      
      final structure = lessonPlan['lessonStructure'] as Map<String, dynamic>;
      
      for (var entry in structure.entries) {
        final sectionName = entry.key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        ).trim().toUpperCase();
        
        buffer.writeln('$sectionName:');
        
        final section = entry.value as Map<String, dynamic>;
        if (section['duration'] != null) {
          buffer.writeln('  Duration: ${section['duration']}');
        }
        
        if (section['activities'] != null) {
          buffer.writeln('  Activities:');
          for (var activity in section['activities'] as List) {
            buffer.writeln('    • $activity');
          }
        }
        
        if (section['teacherActivity'] != null) {
          buffer.writeln('  Teacher Activity:');
          for (var activity in section['teacherActivity'] as List) {
            buffer.writeln('    • $activity');
          }
        }
        
        if (section['studentActivity'] != null) {
          buffer.writeln('  Student Activity:');
          for (var activity in section['studentActivity'] as List) {
            buffer.writeln('    • $activity');
          }
        }
        
        if (section['differentiation'] != null) {
          buffer.writeln('  Differentiation:');
          final diff = section['differentiation'] as Map<String, dynamic>;
          if (diff['support'] != null) buffer.writeln('    Support: ${diff['support']}');
          if (diff['stretch'] != null) buffer.writeln('    Stretch: ${diff['stretch']}');
          if (diff['supportLearners'] != null) buffer.writeln('    Support: ${diff['supportLearners']}');
          if (diff['stretchLearners'] != null) buffer.writeln('    Stretch: ${diff['stretchLearners']}');
        }
        
        if (section['assessment'] != null) {
          buffer.writeln('  Assessment: ${section['assessment']}');
        }
        
        buffer.writeln();
      }
    }
    
    // Assessment
    if (lessonPlan['assessment'] != null) {
      buffer.writeln('ASSESSMENT:');
      final assessment = lessonPlan['assessment'] as Map<String, dynamic>;
      
      if (assessment['formative'] != null) {
        buffer.writeln('  Formative:');
        for (var item in assessment['formative'] as List) {
          buffer.writeln('    • $item');
        }
      }
      
      if (assessment['summative'] != null) {
        buffer.writeln('  Summative:');
        for (var item in assessment['summative'] as List) {
          buffer.writeln('    • $item');
        }
      }
      buffer.writeln();
    }
    
    // Homework
    if (lessonPlan['homework'] != null) {
      buffer.writeln('HOMEWORK:');
      final homework = lessonPlan['homework'];
      if (homework is List) {
        for (var hw in homework) {
          buffer.writeln('  • $hw');
        }
      } else {
        buffer.writeln('  $homework');
      }
      buffer.writeln();
    }
    
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('Generated by Uriel Academy - GES/NACCA Aligned');
    buffer.writeln('═══════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
  
  // Copy lesson plan to clipboard
  void _copyLessonPlan(BuildContext context, Map<String, dynamic> lesson) {
    final text = _formatLessonPlanAsText(lesson);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Lesson plan copied to clipboard!'),
        backgroundColor: Color(0xFF2ECC71),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  // Download lesson plan as formatted text file
  void _downloadLessonPlan(BuildContext context, Map<String, dynamic> lesson) {
    final text = _formatLessonPlanAsText(lesson);
    final lessonPlan = lesson['lessonPlan'] as Map<String, dynamic>?;
    final fileName = '${lessonPlan?['lessonTitle'] ?? 'Lesson_Plan'}'
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\s-]'), '');
    
    final bytes = utf8.encode(text);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$fileName.txt')
      ..click();
    html.Url.revokeObjectUrl(url);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Downloading $fileName.txt'),
        backgroundColor: const Color(0xFF2ECC71),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showLessonDetailsDialog(BuildContext context, Map<String, dynamic> lesson) {
    final lessonPlan = lesson['lessonPlan'] as Map<String, dynamic>?;
    if (lessonPlan == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppStyles.primaryRed,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lessonPlan['lessonTitle'] ?? 'Lesson Plan',
                            style: AppStyles.montserratBold(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lesson['subject'] ?? '',
                            style: AppStyles.montserratMedium(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Copy button
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
                      onPressed: () => _copyLessonPlan(context, lesson),
                      tooltip: 'Copy to clipboard',
                    ),
                    // Download button
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () => _downloadLessonPlan(context, lesson),
                      tooltip: 'Download as text file',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Learning Outcomes
                      if (lessonPlan['learningOutcomes'] != null) ...[
                        Text('Learning Outcomes', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        ...(lessonPlan['learningOutcomes'] as List).map((outcome) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• '),
                                Expanded(child: Text(outcome.toString())),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                      
                      // Prerequisites
                      if (lessonPlan['prerequisites'] != null) ...[
                        Text('Prerequisites', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(lessonPlan['prerequisites'].toString()),
                        const SizedBox(height: 16),
                      ],
                      
                      // Teaching Learning Materials
                      if (lessonPlan['teachingLearningMaterials'] != null) ...[
                        Text('Teaching Learning Materials', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(lessonPlan['teachingLearningMaterials'].toString()),
                        const SizedBox(height: 16),
                      ],
                      
                      // Lesson Structure
                      if (lessonPlan['lessonStructure'] != null) ...[
                        Text('Lesson Structure', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        _buildLessonStructureSection(lessonPlan['lessonStructure']),
                        const SizedBox(height: 16),
                      ],
                      
                      // Assessment
                      if (lessonPlan['assessment'] != null) ...[
                        Text('Assessment', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        _buildAssessmentSection(lessonPlan['assessment']),
                        const SizedBox(height: 16),
                      ],
                      
                      // Homework
                      if (lessonPlan['homework'] != null) ...[
                        Text('Homework', style: AppStyles.montserratBold(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(lessonPlan['homework'].toString()),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLessonStructureSection(dynamic structure) {
    if (structure is! Map) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (structure['intro'] != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Introduction', style: AppStyles.montserratBold(fontSize: 14)),
                const SizedBox(height: 8),
                Text(structure['intro'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (structure['main'] != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Main Activity', style: AppStyles.montserratBold(fontSize: 14)),
                const SizedBox(height: 8),
                Text(structure['main'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (structure['plenary'] != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plenary', style: AppStyles.montserratBold(fontSize: 14)),
                const SizedBox(height: 8),
                Text(structure['plenary'].toString()),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildAssessmentSection(dynamic assessment) {
    if (assessment is! Map) return Text(assessment.toString());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assessment['formative'] != null) ...[
          Text('Formative:', style: AppStyles.montserratBold(fontSize: 14)),
          Text(assessment['formative'].toString()),
          const SizedBox(height: 8),
        ],
        if (assessment['summative'] != null) ...[
          Text('Summative:', style: AppStyles.montserratBold(fontSize: 14)),
          Text(assessment['summative'].toString()),
        ],
      ],
    );
  }
  
  void _showDeleteConfirmationDialog(BuildContext context, Map<String, dynamic> lesson) {
    final lessonPlan = lesson['lessonPlan'] as Map<String, dynamic>?;
    final lessonTitle = lessonPlan?['lessonTitle'] ?? lesson['title'] ?? 'this lesson';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Lesson Plan?',
                style: AppStyles.montserratBold(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "$lessonTitle"?',
              style: AppStyles.montserratRegular(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: AppStyles.montserratMedium(
                        fontSize: 13,
                        color: Colors.red[700]!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppStyles.montserratMedium(color: Colors.grey[700]!),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteLesson(lesson);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, size: 18),
                const SizedBox(width: 8),
                Text('Delete', style: AppStyles.montserratBold()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteLesson(Map<String, dynamic> lesson) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final lessonId = lesson['id'] as String?;
      if (lessonId == null) return;
      
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('lesson_plans')
          .doc(user.uid)
          .collection('plans')
          .doc(lessonId)
          .delete();
      
      // Remove from local state
      setState(() {
        _generatedLessons.removeWhere((l) => l['id'] == lessonId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Lesson plan deleted successfully',
                  style: AppStyles.montserratMedium(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting lesson: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error deleting lesson: $e',
                    style: AppStyles.montserratMedium(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD62828),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
