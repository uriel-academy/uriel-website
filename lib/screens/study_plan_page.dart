import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../constants/app_styles.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({Key? key}) : super(key: key);

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Onboarding state
  int _currentStep = 0;
  bool _hasExistingPlan = false;
  bool _isLoadingPlan = false;
  bool _isGeneratingPlan = false;
  
  // Step 1: Goal Setting
  String _studyGoal = 'Exam preparation';
  DateTime? _examDate;
  final _examDateController = TextEditingController();
  
  // Step 2: Commitments
  int _weeklyHours = 10;
  String _preferredTime = 'Afternoon';
  final Map<String, Map<String, bool>> _availability = {
    'Monday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Tuesday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Wednesday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Thursday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Friday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Saturday': {'Morning': false, 'Afternoon': false, 'Evening': false},
    'Sunday': {'Morning': false, 'Afternoon': false, 'Evening': false},
  };
  
  // Step 3: Subjects
  final List<Map<String, dynamic>> _subjects = [];
  final _subjectController = TextEditingController();
  String _subjectPriority = 'Medium';
  
  final List<String> _beceSubjects = [
    'Mathematics',
    'English Language',
    'Integrated Science',
    'Social Studies',
    'Ghanaian Language',
    'French',
    'ICT',
    'RME',
    'Creative Arts',
  ];
  
  // Step 4: Preferences
  int _sessionLength = 45; // minutes
  int _breakLength = 10; // minutes
  bool _enableReminders = true;
  bool _enableEmailReminders = false;
  
  // Generated plan
  Map<String, dynamic>? _generatedPlan;
  
  // Progress tracking
  Map<String, Map<int, bool>> _sessionCompletions = {}; // day -> sessionIndex -> completed
  int _currentWeek = 1;
  
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
    _subjectController.dispose();
    super.dispose();
  }
  
  Future<void> _checkExistingPlan() async {
    setState(() => _isLoadingPlan = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('study_plans')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _hasExistingPlan = true;
          _generatedPlan = data?['studyPlan'];
          // Load tracking data
          final tracking = data?['tracking'] as Map<String, dynamic>?;
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
      
      // Prepare data for Cloud Function
      final planData = {
        'userId': user.uid,
        'goal': _studyGoal,
        'examDate': _examDate?.toIso8601String(),
        'weeklyHours': _weeklyHours,
        'preferredTime': _preferredTime,
        'availability': _availability,
        'subjects': _subjects,
        'sessionLength': _sessionLength,
        'breakLength': _breakLength,
        'enableReminders': _enableReminders,
        'enableEmailReminders': _enableEmailReminders,
      };
      
      // Call Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('generateStudyPlan');
      final result = await callable.call(planData);
      
      // Extract the studyPlan from the response
      final studyPlan = result.data['studyPlan'];
      final metadata = result.data['metadata'];
      
      setState(() {
        _generatedPlan = studyPlan;
        _hasExistingPlan = true;
        // Initialize tracking data
        _sessionCompletions = {};
      });
      
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('study_plans')
          .doc(user.uid)
          .set({
        ...planData,
        'studyPlan': studyPlan,
        'metadata': metadata,
        'tracking': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
            .collection('study_plans')
            .doc(user.uid)
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
        title: Text('Create New Plan?', style: AppStyles.montserratBold()),
        content: Text(
          'This will replace your current study plan. Your progress will be archived.',
          style: AppStyles.montserratRegular(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppStyles.montserratMedium()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppStyles.primaryRed),
            child: Text('Create New', style: AppStyles.montserratBold(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _hasExistingPlan = false;
        _generatedPlan = null;
        _currentStep = 0;
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
    
    if (_hasExistingPlan && _generatedPlan != null) {
      return _buildStudyPlanView(isSmallScreen);
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
            'Create Your Personalized Study Schedule',
            style: AppStyles.playfairHeading(
              fontSize: isSmallScreen ? 24 : 32,
              color: AppStyles.primaryNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Stay on track with smart reminders and progress tracking',
            style: AppStyles.montserratRegular(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.grey[600]!,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '⏱️ 2 minutes to set up',
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted || isCurrent
                      ? AppStyles.primaryRed
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          '${index + 1}',
                          style: AppStyles.montserratBold(
                            color: isCurrent ? Colors.white : Colors.grey[600]!,
                          ),
                        ),
                ),
              ),
              if (index < 4)
                Container(
                  width: 40,
                  height: 2,
                  color: index < _currentStep
                      ? AppStyles.primaryRed
                      : Colors.grey[300],
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
        return _buildGoalSettingStep(isSmallScreen);
      case 1:
        return _buildCommitmentsStep(isSmallScreen);
      case 2:
        return _buildSubjectsStep(isSmallScreen);
      case 3:
        return _buildPreferencesStep(isSmallScreen);
      case 4:
        return _buildReviewStep(isSmallScreen);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildGoalSettingStep(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step 1: What are you studying for?',
              style: AppStyles.montserratBold(
                fontSize: isSmallScreen ? 18 : 22,
                color: AppStyles.primaryNavy,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                'Exam preparation',
                'Course completion',
                'Skill development',
                'General learning',
              ].map((goal) => ChoiceChip(
                label: Text(goal),
                selected: _studyGoal == goal,
                onSelected: (selected) {
                  setState(() => _studyGoal = goal);
                },
                selectedColor: AppStyles.primaryRed.withOpacity(0.2),
                labelStyle: AppStyles.montserratMedium(
                  color: _studyGoal == goal
                      ? AppStyles.primaryRed
                      : Colors.grey[700]!,
                ),
              )).toList(),
            ),
            if (_studyGoal == 'Exam preparation') ...[
              const SizedBox(height: 24),
              Text(
                'When is your exam?',
                style: AppStyles.montserratBold(
                  fontSize: 16,
                  color: AppStyles.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _examDateController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select exam date',
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) {
                    setState(() {
                      _examDate = date;
                      _examDateController.text = DateFormat('MMMM d, y').format(date);
                    });
                  }
                },
              ),
              if (_examDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2ECC71)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_examDate!.difference(DateTime.now()).inDays} days until your exam',
                          style: AppStyles.montserratMedium(
                            color: const Color(0xFF2ECC71),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
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
                  selectedColor: AppStyles.primaryRed.withOpacity(0.2),
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
                dataRowHeight: 40,
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
                  selectedColor: const Color(0xFF2ECC71).withOpacity(0.2),
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
                color: AppStyles.primaryRed.withOpacity(0.1),
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
                side: BorderSide(color: AppStyles.primaryRed),
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
            onPressed: _isGeneratingPlan
                ? null
                : () {
                    if (_currentStep < 4) {
                      setState(() => _currentStep++);
                    } else {
                      _generateStudyPlan();
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
            child: _isGeneratingPlan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _currentStep < 4 ? 'Next' : 'Generate My Plan',
                    style: AppStyles.montserratBold(fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStudyPlanView(bool isSmallScreen) {
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
      child: Column(
        children: [
          // Header with Create New Plan button
          Container(
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Study Plan',
                        style: AppStyles.playfairHeading(
                          fontSize: isSmallScreen ? 24 : 32,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 24,
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
              padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2ECC71).withOpacity(0.1),
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
                                            fontSize: 18,
                                            color: AppStyles.primaryNavy,
                                          ),
                                        ),
                                        Text(
                                          '$completedSessions of $totalSessions sessions completed',
                                          style: AppStyles.montserratRegular(
                                            fontSize: 14,
                                            color: Colors.grey[600]!,
                                          ),
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
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6A00F4).withOpacity(0.1),
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
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: isCompleted
                                            ? const Color(0xFF2ECC71).withOpacity(0.1)
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCompleted
                                              ? const Color(0xFF2ECC71)
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: isCompleted,
                                          onChanged: (val) => _toggleSessionCompletion(day, sessionIndex),
                                          activeColor: const Color(0xFF2ECC71),
                                        ),
                                        title: Text(
                                          session['subject'] ?? 'Study Session',
                                          style: AppStyles.montserratBold(
                                            fontSize: 16,
                                            color: AppStyles.primaryNavy,
                                          ).copyWith(
                                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              session['topic'] ?? '',
                                              style: AppStyles.montserratRegular(
                                                fontSize: 14,
                                                color: Colors.grey[700]!,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  session['time'] ?? '',
                                                  style: AppStyles.montserratMedium(
                                                    fontSize: 12,
                                                    color: Colors.grey[600]!,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Icon(Icons.task_alt, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  session['activity'] ?? '',
                                                  style: AppStyles.montserratMedium(
                                                    fontSize: 12,
                                                    color: Colors.grey[600]!,
                                                  ),
                                                ),
                                              ],
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
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
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
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
