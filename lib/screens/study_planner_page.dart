import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudyPlannerPage extends StatefulWidget {
  const StudyPlannerPage({super.key});

  @override
  State<StudyPlannerPage> createState() => _StudyPlannerPageState();
}

class _StudyPlannerPageState extends State<StudyPlannerPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form values
  String? _selectedExam;
  String? _selectedGrade;
  DateTime? _examDate;
  int _studyHoursPerDay = 2;
  final List<String> _weakSubjects = [];
  
  final List<String> _exams = ['BECE', 'WASSCE', 'NOVDEC'];
  final List<String> _grades = ['JHS 1', 'JHS 2', 'JHS 3', 'SHS 1', 'SHS 2', 'SHS 3'];
  final List<String> _subjects = [
    'Math', 'English', 'Biology', 'Chemistry', 'Physics', 
    'Economics', 'Literature', 'Civic', 'Geography', 'History', 
    'Further Math', 'Computer', 'RME', 'Science'
  ];
  
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('AI Study Planner'),
        backgroundColor: const Color(0xFF1A1E3F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildExamTypeCard(),
              const SizedBox(height: 16),
              _buildGradeCard(),
              const SizedBox(height: 16),
              _buildExamDateCard(),
              const SizedBox(height: 16),
              _buildStudyHoursCard(),
              const SizedBox(height: 16),
              _buildWeakSubjectsCard(),
              const SizedBox(height: 32),
              _buildGenerateButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD62828).withValues(alpha: 0.1),
            const Color(0xFF1A1E3F).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Create Your Smart Study Plan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1E3F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Our AI will analyze your needs and create a personalized study plan that helps you master all features of Uriel Academy efficiently.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamTypeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Target Exam',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedExam,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.school),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              hint: const Text('Select your exam'),
              items: _exams.map((exam) {
                return DropdownMenuItem(value: exam, child: Text(exam));
              }).toList(),
              onChanged: (value) => setState(() => _selectedExam = value),
              validator: (value) => value == null ? 'Please select an exam' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Grade/Form',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.grade),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              hint: const Text('Select your current grade'),
              items: _grades.map((grade) {
                return DropdownMenuItem(value: grade, child: Text(grade));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGrade = value),
              validator: (value) => value == null ? 'Please select your grade' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamDateCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (date != null) setState(() => _examDate = date);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Text(
                      _examDate == null
                          ? 'Select exam date'
                          : DateFormat('MMMM dd, yyyy').format(_examDate!),
                      style: TextStyle(
                        fontSize: 16,
                        color: _examDate == null ? Colors.grey[600] : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_examDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_examDate!.difference(DateTime.now()).inDays} days until exam',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudyHoursCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Study Hours per Day',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFFD62828)),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _studyHoursPerDay.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    activeColor: const Color(0xFFD62828),
                    label: '$_studyHoursPerDay hours',
                    onChanged: (value) => setState(() => _studyHoursPerDay = value.toInt()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_studyHoursPerDay hrs',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD62828),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakSubjectsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subjects Needing Extra Focus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjects.map((subject) {
                final isSelected = _weakSubjects.contains(subject);
                return FilterChip(
                  label: Text(subject),
                  selected: isSelected,
                  selectedColor: const Color(0xFFD62828).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFFD62828),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _weakSubjects.add(subject);
                      } else {
                        _weakSubjects.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected ${_weakSubjects.length} subject(s)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateStudyPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD62828),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isGenerating
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Generate My AI Study Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _generateStudyPlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exam date')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Calculate days until exam
      final daysUntilExam = _examDate!.difference(DateTime.now()).inDays;
      
      // Generate weekly goals based on user preferences
      final weeklyGoals = _calculateWeeklyGoals(daysUntilExam);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('study_plan')
          .doc('current')
          .set({
        'exam_type': _selectedExam,
        'grade': _selectedGrade,
        'exam_date': Timestamp.fromDate(_examDate!),
        'study_hours_per_day': _studyHoursPerDay,
        'weak_subjects': _weakSubjects,
        'weekly_goals': weeklyGoals,
        'progress': {
          'past_questions': 0,
          'textbook_chapters': 0,
          'ai_sessions': 0,
          'trivia_games': 0,
        },
        'created_at': FieldValue.serverTimestamp(),
        'days_until_exam': daysUntilExam,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Study plan created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Map<String, int> _calculateWeeklyGoals(int daysUntilExam) {
    // Base multiplier based on study hours
    final multiplier = _studyHoursPerDay / 2;
    
    // Adjust intensity based on time available
    final intensityFactor = daysUntilExam < 30 ? 1.5 : daysUntilExam < 90 ? 1.2 : 1.0;
    
    // Extra focus on weak subjects
    final weakSubjectBonus = _weakSubjects.isNotEmpty ? 1.3 : 1.0;

    return {
      'past_questions': ((15 * multiplier * intensityFactor * weakSubjectBonus).round()),
      'textbook_chapters': ((3 * multiplier * intensityFactor).round()),
      'ai_sessions': ((4 * multiplier * intensityFactor).round()),
      'trivia_games': ((5 * multiplier).round()),
    };
  }
}
